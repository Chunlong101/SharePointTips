namespace IntermittentIssueDetector
{
    partial class Form1
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.components = new System.ComponentModel.Container();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Form1));
            this.timer1 = new System.Windows.Forms.Timer(this.components);
            this.urlTextBox = new MetroFramework.Controls.MetroTextBox();
            this.frequencyTextBox = new MetroFramework.Controls.MetroTextBox();
            this.SuccessTagTextBox = new MetroFramework.Controls.MetroTextBox();
            this.goButton = new MetroFramework.Controls.MetroButton();
            this.webView21 = new Microsoft.Web.WebView2.WinForms.WebView2();
            this.notifyIcon1 = new System.Windows.Forms.NotifyIcon(this.components);
            this.metroContextMenu1 = new MetroFramework.Controls.MetroContextMenu(this.components);
            this.openToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.runInBackgroundToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.exitToolStripMenuItem = new System.Windows.Forms.ToolStripMenuItem();
            this.openLogButton = new MetroFramework.Controls.MetroButton();
            this.stopButton = new MetroFramework.Controls.MetroButton();
            this.panel1 = new System.Windows.Forms.Panel();
            ((System.ComponentModel.ISupportInitialize)(this.webView21)).BeginInit();
            this.metroContextMenu1.SuspendLayout();
            this.panel1.SuspendLayout();
            this.SuspendLayout();
            // 
            // timer1
            // 
            this.timer1.Interval = 999999999;
            this.timer1.Tick += new System.EventHandler(this.timer1_Tick);
            // 
            // urlTextBox
            // 
            // 
            // 
            // 
            this.urlTextBox.CustomButton.Image = null;
            this.urlTextBox.CustomButton.Location = new System.Drawing.Point(374, 2);
            this.urlTextBox.CustomButton.Name = "";
            this.urlTextBox.CustomButton.Size = new System.Drawing.Size(39, 39);
            this.urlTextBox.CustomButton.Style = MetroFramework.MetroColorStyle.Blue;
            this.urlTextBox.CustomButton.TabIndex = 1;
            this.urlTextBox.CustomButton.Theme = MetroFramework.MetroThemeStyle.Light;
            this.urlTextBox.CustomButton.UseSelectable = true;
            this.urlTextBox.CustomButton.Visible = false;
            this.urlTextBox.Lines = new string[] {
        "Pls input your web url here, for example: https://github.com/Chunlong101"};
            this.urlTextBox.Location = new System.Drawing.Point(3, 17);
            this.urlTextBox.MaxLength = 32767;
            this.urlTextBox.Name = "urlTextBox";
            this.urlTextBox.PasswordChar = '\0';
            this.urlTextBox.ScrollBars = System.Windows.Forms.ScrollBars.None;
            this.urlTextBox.SelectedText = "";
            this.urlTextBox.SelectionLength = 0;
            this.urlTextBox.SelectionStart = 0;
            this.urlTextBox.ShortcutsEnabled = true;
            this.urlTextBox.Size = new System.Drawing.Size(652, 44);
            this.urlTextBox.TabIndex = 2;
            this.urlTextBox.Text = "Pls input your web url here, for example: https://github.com/Chunlong101";
            this.urlTextBox.UseSelectable = true;
            this.urlTextBox.WaterMarkColor = System.Drawing.Color.FromArgb(((int)(((byte)(109)))), ((int)(((byte)(109)))), ((int)(((byte)(109)))));
            this.urlTextBox.WaterMarkFont = new System.Drawing.Font("Segoe UI", 12F, System.Drawing.FontStyle.Italic, System.Drawing.GraphicsUnit.Pixel);
            this.urlTextBox.KeyDown += new System.Windows.Forms.KeyEventHandler(this.urlTextBox_KeyDown);
            // 
            // frequencyTextBox
            // 
            // 
            // 
            // 
            this.frequencyTextBox.CustomButton.Image = null;
            this.frequencyTextBox.CustomButton.Location = new System.Drawing.Point(54, 2);
            this.frequencyTextBox.CustomButton.Name = "";
            this.frequencyTextBox.CustomButton.Size = new System.Drawing.Size(39, 39);
            this.frequencyTextBox.CustomButton.Style = MetroFramework.MetroColorStyle.Blue;
            this.frequencyTextBox.CustomButton.TabIndex = 1;
            this.frequencyTextBox.CustomButton.Theme = MetroFramework.MetroThemeStyle.Light;
            this.frequencyTextBox.CustomButton.UseSelectable = true;
            this.frequencyTextBox.CustomButton.Visible = false;
            this.frequencyTextBox.Lines = new string[] {
        "Frequency"};
            this.frequencyTextBox.Location = new System.Drawing.Point(767, 18);
            this.frequencyTextBox.MaxLength = 32767;
            this.frequencyTextBox.Name = "frequencyTextBox";
            this.frequencyTextBox.PasswordChar = '\0';
            this.frequencyTextBox.ScrollBars = System.Windows.Forms.ScrollBars.None;
            this.frequencyTextBox.SelectedText = "";
            this.frequencyTextBox.SelectionLength = 0;
            this.frequencyTextBox.SelectionStart = 0;
            this.frequencyTextBox.ShortcutsEnabled = true;
            this.frequencyTextBox.Size = new System.Drawing.Size(96, 44);
            this.frequencyTextBox.TabIndex = 4;
            this.frequencyTextBox.Text = "Frequency";
            this.frequencyTextBox.UseSelectable = true;
            this.frequencyTextBox.WaterMarkColor = System.Drawing.Color.FromArgb(((int)(((byte)(109)))), ((int)(((byte)(109)))), ((int)(((byte)(109)))));
            this.frequencyTextBox.WaterMarkFont = new System.Drawing.Font("Segoe UI", 12F, System.Drawing.FontStyle.Italic, System.Drawing.GraphicsUnit.Pixel);
            // 
            // SuccessTagTextBox
            // 
            // 
            // 
            // 
            this.SuccessTagTextBox.CustomButton.Image = null;
            this.SuccessTagTextBox.CustomButton.Location = new System.Drawing.Point(294, 2);
            this.SuccessTagTextBox.CustomButton.Name = "";
            this.SuccessTagTextBox.CustomButton.Size = new System.Drawing.Size(39, 39);
            this.SuccessTagTextBox.CustomButton.Style = MetroFramework.MetroColorStyle.Blue;
            this.SuccessTagTextBox.CustomButton.TabIndex = 1;
            this.SuccessTagTextBox.CustomButton.Theme = MetroFramework.MetroThemeStyle.Light;
            this.SuccessTagTextBox.CustomButton.UseSelectable = true;
            this.SuccessTagTextBox.CustomButton.Visible = false;
            this.SuccessTagTextBox.Lines = new string[] {
        "SuccessTag"};
            this.SuccessTagTextBox.Location = new System.Drawing.Point(661, 18);
            this.SuccessTagTextBox.MaxLength = 32767;
            this.SuccessTagTextBox.Name = "SuccessTagTextBox";
            this.SuccessTagTextBox.PasswordChar = '\0';
            this.SuccessTagTextBox.ScrollBars = System.Windows.Forms.ScrollBars.None;
            this.SuccessTagTextBox.SelectedText = "";
            this.SuccessTagTextBox.SelectionLength = 0;
            this.SuccessTagTextBox.SelectionStart = 0;
            this.SuccessTagTextBox.ShortcutsEnabled = true;
            this.SuccessTagTextBox.Size = new System.Drawing.Size(100, 44);
            this.SuccessTagTextBox.TabIndex = 6;
            this.SuccessTagTextBox.Text = "SuccessTag";
            this.SuccessTagTextBox.UseSelectable = true;
            this.SuccessTagTextBox.WaterMarkColor = System.Drawing.Color.FromArgb(((int)(((byte)(109)))), ((int)(((byte)(109)))), ((int)(((byte)(109)))));
            this.SuccessTagTextBox.WaterMarkFont = new System.Drawing.Font("Segoe UI", 12F, System.Drawing.FontStyle.Italic, System.Drawing.GraphicsUnit.Pixel);
            // 
            // goButton
            // 
            this.goButton.Location = new System.Drawing.Point(867, 17);
            this.goButton.Name = "goButton";
            this.goButton.Size = new System.Drawing.Size(114, 43);
            this.goButton.TabIndex = 7;
            this.goButton.Text = "Go";
            this.goButton.UseSelectable = true;
            this.goButton.Click += new System.EventHandler(this.goButton_Click);
            // 
            // webView21
            // 
            this.webView21.AllowExternalDrop = true;
            this.webView21.CreationProperties = null;
            this.webView21.DefaultBackgroundColor = System.Drawing.Color.White;
            this.webView21.Dock = System.Windows.Forms.DockStyle.Fill;
            this.webView21.Location = new System.Drawing.Point(20, 100);
            this.webView21.Name = "webView21";
            this.webView21.Size = new System.Drawing.Size(1270, 309);
            this.webView21.TabIndex = 9;
            this.webView21.ZoomFactor = 1D;
            // 
            // notifyIcon1
            // 
            this.notifyIcon1.BalloonTipText = "Intermittent Issue Detector";
            this.notifyIcon1.ContextMenuStrip = this.metroContextMenu1;
            this.notifyIcon1.Icon = ((System.Drawing.Icon)(resources.GetObject("notifyIcon1.Icon")));
            this.notifyIcon1.Text = "Intermittent Issue Detector";
            this.notifyIcon1.MouseClick += new System.Windows.Forms.MouseEventHandler(this.notifyIcon1_MouseClick);
            this.notifyIcon1.MouseDoubleClick += new System.Windows.Forms.MouseEventHandler(this.notifyIcon1_MouseDoubleClick);
            // 
            // metroContextMenu1
            // 
            this.metroContextMenu1.ImageScalingSize = new System.Drawing.Size(24, 24);
            this.metroContextMenu1.Items.AddRange(new System.Windows.Forms.ToolStripItem[] {
            this.openToolStripMenuItem,
            this.runInBackgroundToolStripMenuItem,
            this.exitToolStripMenuItem});
            this.metroContextMenu1.Name = "metroContextMenu1";
            this.metroContextMenu1.ShowItemToolTips = false;
            this.metroContextMenu1.Size = new System.Drawing.Size(266, 100);
            // 
            // openToolStripMenuItem
            // 
            this.openToolStripMenuItem.Name = "openToolStripMenuItem";
            this.openToolStripMenuItem.Size = new System.Drawing.Size(265, 32);
            this.openToolStripMenuItem.Text = "Open";
            this.openToolStripMenuItem.Click += new System.EventHandler(this.openToolStripMenuItem_Click);
            // 
            // runInBackgroundToolStripMenuItem
            // 
            this.runInBackgroundToolStripMenuItem.Name = "runInBackgroundToolStripMenuItem";
            this.runInBackgroundToolStripMenuItem.Size = new System.Drawing.Size(265, 32);
            this.runInBackgroundToolStripMenuItem.Text = "Run in the background";
            this.runInBackgroundToolStripMenuItem.Click += new System.EventHandler(this.runInBackgroundToolStripMenuItem_Click);
            // 
            // exitToolStripMenuItem
            // 
            this.exitToolStripMenuItem.Name = "exitToolStripMenuItem";
            this.exitToolStripMenuItem.Size = new System.Drawing.Size(265, 32);
            this.exitToolStripMenuItem.Text = "Exit";
            this.exitToolStripMenuItem.Click += new System.EventHandler(this.exitToolStripMenuItem_Click);
            // 
            // openLogButton
            // 
            this.openLogButton.Location = new System.Drawing.Point(1107, 17);
            this.openLogButton.Name = "openLogButton";
            this.openLogButton.Size = new System.Drawing.Size(159, 43);
            this.openLogButton.TabIndex = 10;
            this.openLogButton.Text = "Open Log File";
            this.openLogButton.UseSelectable = true;
            this.openLogButton.Click += new System.EventHandler(this.openLogButton_Click);
            // 
            // stopButton
            // 
            this.stopButton.Location = new System.Drawing.Point(987, 17);
            this.stopButton.Name = "stopButton";
            this.stopButton.Size = new System.Drawing.Size(114, 43);
            this.stopButton.TabIndex = 11;
            this.stopButton.Text = "Stop";
            this.stopButton.UseSelectable = true;
            this.stopButton.Click += new System.EventHandler(this.stopButton_Click);
            // 
            // panel1
            // 
            this.panel1.Controls.Add(this.urlTextBox);
            this.panel1.Controls.Add(this.frequencyTextBox);
            this.panel1.Controls.Add(this.stopButton);
            this.panel1.Controls.Add(this.SuccessTagTextBox);
            this.panel1.Controls.Add(this.openLogButton);
            this.panel1.Controls.Add(this.goButton);
            this.panel1.Dock = System.Windows.Forms.DockStyle.Top;
            this.panel1.Location = new System.Drawing.Point(20, 100);
            this.panel1.Name = "panel1";
            this.panel1.Size = new System.Drawing.Size(1270, 78);
            this.panel1.TabIndex = 12;
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(9F, 20F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1310, 429);
            this.Controls.Add(this.panel1);
            this.Controls.Add(this.webView21);
            this.Icon = ((System.Drawing.Icon)(resources.GetObject("$this.Icon")));
            this.Name = "Form1";
            this.Padding = new System.Windows.Forms.Padding(20, 100, 20, 20);
            this.Text = "Intermittent Issue Dectector";
            this.TextAlign = MetroFramework.Forms.MetroFormTextAlign.Center;
            this.Theme = MetroFramework.MetroThemeStyle.Dark;
            this.Load += new System.EventHandler(this.Form1_Load);
            this.Resize += new System.EventHandler(this.Form1_Resize);
            ((System.ComponentModel.ISupportInitialize)(this.webView21)).EndInit();
            this.metroContextMenu1.ResumeLayout(false);
            this.panel1.ResumeLayout(false);
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.Timer timer1;
        private MetroFramework.Controls.MetroTextBox urlTextBox;
        private MetroFramework.Controls.MetroTextBox frequencyTextBox;
        private MetroFramework.Controls.MetroTextBox SuccessTagTextBox;
        private MetroFramework.Controls.MetroButton goButton;
        private Microsoft.Web.WebView2.WinForms.WebView2 webView21;
        private System.Windows.Forms.NotifyIcon notifyIcon1;
        private MetroFramework.Controls.MetroContextMenu metroContextMenu1;
        private System.Windows.Forms.ToolStripMenuItem runInBackgroundToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem exitToolStripMenuItem;
        private System.Windows.Forms.ToolStripMenuItem openToolStripMenuItem;
        private MetroFramework.Controls.MetroButton openLogButton;
        private MetroFramework.Controls.MetroButton stopButton;
        private System.Windows.Forms.Panel panel1;
    }
}

