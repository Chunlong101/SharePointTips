#!/usr/bin/env python3
"""
HAR Splitter (robust + URL filtering)
-------------------------------------
Split a large .har (HTTP Archive) file into smaller parts. Adds recovery options when the HAR is
not strictly valid JSON (e.g., BOM, comments, trailing commas) and can diagnose/skip bad entries.
Now also supports filtering entries by URL substring(s) or regex before splitting.

Usage examples:
  # Basic split by ~10MB target size
  python har_splitter.py big.har --size-mb 10

  # Split by fixed entries count
  python har_splitter.py big.har --entries-per-file 2000

  # Gzip outputs
  python har_splitter.py big.har --size-mb 10 --gzip

  # Diagnose invalid entry
  python har_splitter.py big.har --diagnose -o har_diag

  # Skip invalid entries and split
  python har_splitter.py big.har --skip-bad --size-mb 10

  # --- URL filtering ---
  # Keep only requests whose URL contains "sharepoint" (case-insensitive)
  python har_splitter.py big.har --size-mb 10 --filter-url-contains sharepoint

  # Multiple substrings (logical OR): keep URLs containing ANY of them
  python har_splitter.py big.har --filter-url-contains sharepoint onedrive office

  # Regex filter (case-insensitive)
  python har_splitter.py big.har --filter-url-regex \\
      ".*(sharepoint\\.cn|sharepoint\\.com|office365\\.com).*"

Notes:
- Filtering is applied BEFORE size estimation and splitting.
- When both --filter-url-contains and --filter-url-regex are provided, an entry is kept if it
  matches EITHER condition (logical OR).
- Gzip auto-detection supported; .har.gz or .har with gzip content works.

---

## 用法

### 只保留 URL 中包含 `sharepoint` 的请求（不区分大小写）
```bash
python har_splitter.py xxx.har --size-mb 10 --filter-url-contains sharepoint
```

### 多关键词任意命中（逻辑 OR）
```bash
python har_splitter.py xxx.har --filter-url-contains sharepoint onedrive office --size-mb 10
```

### 使用正则（例如匹配 `sharepoint.cn` 或 `sharepoint.com` 或 `office365.com`）
```bash
python har_splitter.py xxx.har --filter-url-regex ".*(sharepoint\\.cn|sharepoint\\.com|office365\\.com).*" --size-mb 10
```

> 筛选会在**拆分前**执行，脚本会打印筛选前后条数和保留比例，方便你确认范围。

---

## 还能与容错/诊断一起用

- **自动修复 + 筛选 + 拆分**
  ```bash
  python har_splitter.py xxx.har --filter-url-contains sharepoint --size-mb 10
  ```
- **跳过坏条目 + 筛选 + 拆分**
  ```bash
  python har_splitter.py xxx.har --skip-bad --filter-url-contains sharepoint --size-mb 10
  ```
- **先定位坏条目**
  ```bash
  python har_splitter.py xxx.har --diagnose -o har_diag
  ```

### 其他常用参数
- 输出压缩：`--gzip`（生成 `.har.gz`）
- 固定条数拆分：`--entries-per-file 2000`
- 指定输出目录：`-o out_parts`

---
"""

import argparse
import gzip
import json
import math
import os
import re
import sys
from typing import List, Dict, Any, Set, Tuple, Optional

# ---------------- Utils ----------------

def human_bytes(n: int) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024 or unit == "TB":
            return f"{n:.2f} {unit}" if unit != "B" else f"{n} {unit}"
        n /= 1024
    return f"{n:.2f} TB"


def read_text_auto(path: str) -> str:
    """Read text with BOM/gzip auto-detection."""
    with open(path, 'rb') as fb:
        head = fb.read(4)
        fb.seek(0)
        # gzip
        if head[:2] == b'\x1f\x8b':
            with gzip.open(fb, 'rt', encoding='utf-8', errors='replace') as f:
                return f.read()
        # UTF-16 BOMs
        if head.startswith(b'\xff\xfe'):
            return fb.read().decode('utf-16-le', errors='replace')
        if head.startswith(b'\xfe\xff'):
            return fb.read().decode('utf-16-be', errors='replace')
        # default utf-8
        return fb.read().decode('utf-8', errors='replace')


def write_json(path: str, data: Dict[str, Any], gzip_out: bool = False) -> None:
    if gzip_out:
        if not path.endswith('.gz'):
            path += '.gz'
        with gzip.open(path, 'wt', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False)
    else:
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False)


# ------------- Tolerant JSON load -------------

def basic_repair(text: str) -> str:
    # Strip BOM char
    text = text.lstrip('\ufeff')
    # Remove // line comments
    text = re.sub(r"(?m)//.*?$", "", text)
    # Remove /* */ block comments
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    # Remove trailing commas before } or ]
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return text


def try_load_json_strict_then_repair(text: str) -> Dict[str, Any]:
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        repaired = basic_repair(text)
        return json.loads(repaired)


# ------------- Streaming entry extraction -------------

def find_entries_array_span(text: str) -> Tuple[int, int, int]:
    m = re.search(r'"entries"\s*:\s*\[', text)
    if not m:
        raise ValueError('Cannot locate "log.entries" array in HAR text')
    lbrack = m.end() - 1
    i = lbrack
    depth = 0
    in_str = False
    esc = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == '[':
                depth += 1
            elif ch == ']':
                depth -= 1
                if depth == 0:
                    return (m.start(), lbrack, i)
        i += 1
    raise ValueError('Unterminated entries array')


def iterate_entry_strings(text: str, lbrack: int, rbrack: int):
    i = lbrack + 1
    while i < rbrack and text[i].isspace():
        i += 1
    while i < rbrack:
        if text[i] == ']':
            break
        if text[i] == ',':
            i += 1
            while i < rbrack and text[i].isspace():
                i += 1
            continue
        if text[i] != '{':
            j = text.find('{', i, rbrack)
            if j == -1:
                break
            i = j
        start = i
        depth = 0
        in_str = False
        esc = False
        while i <= rbrack:
            ch = text[i]
            if in_str:
                if esc:
                    esc = False
                elif ch == '\\':
                    esc = True
                elif ch == '"':
                    in_str = False
            else:
                if ch == '"':
                    in_str = True
                elif ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        yield text[start:i+1]
                        i += 1
                        break
            i += 1
        while i <= rbrack and text[i].isspace():
            i += 1
        if i <= rbrack and text[i] == ',':
            i += 1
        while i <= rbrack and i < len(text) and text[i].isspace():
            i += 1


def parse_header_without_entries(text: str) -> Dict[str, Any]:
    ks, l, r = find_entries_array_span(text)
    new_text = text[:l+1] + ']' + text[r+1:]
    return try_load_json_strict_then_repair(new_text)


# ------------- Filtering -------------

def entry_url(entry: Dict[str, Any]) -> str:
    try:
        return str(entry.get('request', {}).get('url', ''))
    except Exception:
        return ''


def filter_entries_by_url(entries: List[Dict[str, Any]], contains: Optional[List[str]] = None,
                          regex: Optional[str] = None) -> List[Dict[str, Any]]:
    if not contains and not regex:
        return entries

    contains_norm: List[str] = []
    if contains:
        for c in contains:
            if c is None:
                continue
            c = c.strip()
            if c:
                contains_norm.append(c.lower())

    pattern = re.compile(regex, re.I) if regex else None

    kept: List[Dict[str, Any]] = []
    for e in entries:
        url = entry_url(e)
        u = url.lower()
        ok = False
        if contains_norm:
            if any(s in u for s in contains_norm):
                ok = True
        if not ok and pattern is not None:
            if pattern.search(url or ''):
                ok = True
        if ok:
            kept.append(e)
    return kept


# ------------- Splitter core -------------

def estimate_entries_per_file(entries_count: int, sample_entries: List[Dict[str, Any]], target_mb: float) -> int:
    if not sample_entries:
        return max(1, entries_count)
    sample_bytes = len(json.dumps(sample_entries, ensure_ascii=False).encode('utf-8'))
    avg_entry_bytes = max(1, sample_bytes // len(sample_entries))
    target_bytes = int(target_mb * 1024 * 1024)
    return max(1, target_bytes // avg_entry_bytes)


def build_har_part(log: Dict[str, Any], entries_chunk: List[Dict[str, Any]]) -> Dict[str, Any]:
    original_pages = log.get('pages', []) or []
    pagerefs: Set[str] = set()
    for e in entries_chunk:
        pr = e.get('pageref')
        if isinstance(pr, str):
            pagerefs.add(pr)
    pages_filtered = [p for p in original_pages if isinstance(p, dict) and p.get('id') in pagerefs]

    new_log: Dict[str, Any] = {
        'version': log.get('version', '1.2'),
        'creator': log.get('creator', {}),
    }
    if 'browser' in log:
        new_log['browser'] = log['browser']
    if pages_filtered:
        new_log['pages'] = pages_filtered
    elif original_pages:
        new_log['pages'] = original_pages[:1]
    new_log['entries'] = entries_chunk
    if 'comment' in log:
        new_log['comment'] = log['comment']
    return {'log': new_log}


def split_har(input_path: str, out_dir: str, size_mb: float = None, entries_per_file: int = None, gzip_out: bool = False,
              skip_bad: bool = False, diagnose: bool = False,
              filter_contains: Optional[List[str]] = None, filter_regex: Optional[str] = None) -> List[str]:
    os.makedirs(out_dir, exist_ok=True)

    text = read_text_auto(input_path)

    # Try strict load first, then repair
    har: Optional[Dict[str, Any]] = None
    entries: Optional[List[Dict[str, Any]]] = None

    try:
        har = json.loads(text)
        entries = har['log']['entries']
    except Exception:
        try:
            har = try_load_json_strict_then_repair(text)
            entries = har['log']['entries']
        except Exception as e:
            if not (skip_bad or diagnose):
                raise ValueError(f"HAR JSON 解析失败，且未启用 --skip-bad/--diagnose。原始错误：{e}")

    if diagnose:
        try:
            ks, l, r = find_entries_array_span(text)
        except Exception as e:
            raise ValueError(f"无法定位 entries 数组：{e}")
        bad_count = 0
        idx = 0
        first_bad_saved = False
        for s in iterate_entry_strings(text, l, r):
            idx += 1
            try:
                json.loads(s)
            except Exception as ex:
                bad_count += 1
                if not first_bad_saved:
                    bad_path = os.path.join(out_dir, f"bad_entry_{idx}.json")
                    with open(bad_path, 'w', encoding='utf-8') as f:
                        f.write(s)
                    print(f"发现无效条目：index={idx}，已保存到 {bad_path}")
                    first_bad_saved = True
        if bad_count == 0:
            print("未发现无法解析的 entry；可能是全局结构问题（如尾随逗号）。")
        else:
            print(f"共发现 {bad_count} 个无法解析的 entry。示例已导出。")
        return []

    if entries is None:
        # Use skip_bad streaming path to build entries list
        ks, l, r = find_entries_array_span(text)
        header = parse_header_without_entries(text)
        log_meta = header['log']
        good_entries: List[Dict[str, Any]] = []
        idx = 0
        bad = 0
        for s in iterate_entry_strings(text, l, r):
            idx += 1
            try:
                good_entries.append(json.loads(s))
            except Exception:
                bad += 1
        print(f"按 skip_bad 模式解析完成：有效 entries={len(good_entries)}，损坏 entries={bad}")
        har = {'log': log_meta}
        entries = good_entries

    # --- Apply URL filtering BEFORE splitting ---
    total_before = len(entries)
    entries = filter_entries_by_url(entries, filter_contains, filter_regex)
    total_after = len(entries)
    if filter_contains or filter_regex:
        print("URL 过滤：从 {} 条降到 {} 条 ({}%)".format(
            total_before, total_after,
            0 if total_before == 0 else round(100.0 * total_after / total_before, 2)))

    total = len(entries)
    if total == 0:
        raise ValueError('过滤后没有可用的 entries。请调整 --filter-url-contains 或 --filter-url-regex。')

    if entries_per_file is None:
        if size_mb is None:
            size_mb = 10.0
        sample = entries[: min(200, total)]
        entries_per_file = estimate_entries_per_file(total, sample, size_mb)

    entries_per_file = max(1, int(entries_per_file))

    parts = math.ceil(total / entries_per_file)
    base = os.path.splitext(os.path.basename(input_path))[0]

    written_paths: List[str] = []

    print(f"Total entries: {total}")
    print(f"Entries per file: {entries_per_file}")
    print(f"Planned parts: {parts}")

    log = har['log']

    for i in range(parts):
        start = i * entries_per_file
        end = min(start + entries_per_file, total)
        chunk = entries[start:end]
        har_part = build_har_part(log, chunk)
        out_name = f"{base}_part{str(i+1).zfill(3)}.har"
        out_path = os.path.join(out_dir, out_name)
        write_json(out_path, har_part, gzip_out=gzip_out)
        try:
            size = os.path.getsize(out_path if not gzip_out else out_path + '.gz')
        except Exception:
            size = 0
        print(f"Wrote {out_name}{'.gz' if gzip_out else ''} with {len(chunk)} entries (~{human_bytes(size)})")
        written_paths.append(out_path + ('.gz' if gzip_out else ''))

    return written_paths


def main():
    parser = argparse.ArgumentParser(description='Split a large HAR file into smaller parts with robust parsing and URL filtering.')
    parser.add_argument('input', help='Path to input .har or .har.gz file')
    parser.add_argument('-o', '--out-dir', default='har_parts', help='Output directory (default: har_parts)')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--size-mb', type=float, help='Target size per output file in MB (approximate)')
    group.add_argument('--entries-per-file', type=int, help='Number of entries per output file')
    parser.add_argument('--gzip', action='store_true', help='Compress outputs as .har.gz')
    parser.add_argument('--diagnose', action='store_true', help='Find and export the first bad entry (if any)')
    parser.add_argument('--skip-bad', action='store_true', help='Skip entries that are not valid JSON (streaming mode)')

    # URL filters
    parser.add_argument('--filter-url-contains', nargs='+', help='Keep entries whose URL contains ANY of these substrings (case-insensitive). Provide one or more.')
    parser.add_argument('--filter-url-regex', help='Keep entries whose URL matches this regex (case-insensitive).')

    args = parser.parse_args()

    try:
        written = split_har(
            input_path=args.input,
            out_dir=args.out_dir,
            size_mb=args.size_mb,
            entries_per_file=args.entries_per_file,
            gzip_out=args.gzip,
            skip_bad=args.skip_bad,
            diagnose=args.diagnose,
            filter_contains=args.filter_url_contains,
            filter_regex=args.filter_url_regex,
        )
        if args.diagnose:
            print("\nDiagnose finished.")
        else:
            print(f"\nDone. Wrote {len(written)} file(s) to: {args.out_dir}")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
