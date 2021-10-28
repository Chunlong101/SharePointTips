# This script aims at simulating high memory situation for testing purpose 
$mem_stress = "a" * 200MB
$mem_stress = @()
for ($i = 0; $i -lt 99999; $i++) { $mem_stress += ("a" * 200MB) }