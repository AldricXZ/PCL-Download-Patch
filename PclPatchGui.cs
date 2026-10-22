using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Shapes;
using WpfPath = System.Windows.Shapes.Path;

namespace PclPatchGui
{
    public class App : Application
    {
        /// <summary>引擎目录：%LOCALAPPDATA%\PCLPatchEngine（内嵌资源首次运行时释放）</summary>
        public static string EngineDir { get; private set; }

        [STAThread]
        public static void Main(string[] args)
        {
            // 引擎释放：Patcher.ps1 / cecil / 守护 exe 全部内嵌在 exe 资源里，
            // 首次运行释放到固定目录；目录已存在则跳过（状态文件、原始备份都在里面，不能动）
            EngineDir = System.IO.Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PCLPatchEngine");
            try
            {
                EnsureEngine();
            }
            catch (Exception ex)
            {
                MessageBox.Show("初始化补丁引擎失败：\n" + ex.Message +
                    "\n\n请确认本程序未被杀毒软件拦截后重试。", "PCL 下载补丁",
                    MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            // 命令行：argv[0] 可为拖入的启动器 exe（预填路径）；
            // argv[1] 为 "none" 时选「不自动修复」并直接开始打补丁（常规版 bat 用）
            string presetPath = args != null && args.Length > 0 ? args[0] : null;
            bool autoNone = args != null && args.Length > 1 && args[1] == "none";

            var app = new App();
            var win = new MainWindow(presetPath, autoNone);
            app.Run(win);
        }

        static void EnsureEngine()
        {
            var asm = System.Reflection.Assembly.GetExecutingAssembly();
            // 资源名形如 pcl.engine.Patcher.ps1 / pcl.engine.cecil.net40.Mono.Cecil.dll：
            // 仅 cecil 段的点代表目录分隔（cecil.<子目录>.<文件>），其余保持原样
            string[] names = asm.GetManifestResourceNames();
            bool any = false;
            foreach (string n in names)
            {
                if (!n.StartsWith("pcl.engine.")) continue;
                any = true;
                string rel = n.Substring("pcl.engine.".Length);
                if (rel.StartsWith("cecil."))
                {
                    // cecil.net40.Mono.Cecil.dll → cecil\net40\Mono.Cecil.dll：
                    // 只展开子目录段（net40 / netstandard2.0），文件名内的点保持原样
                    string rest = rel.Substring("cecil.".Length);
                    foreach (string sub in new string[] { "net40", "netstandard2.0" })
                    {
                        if (rest.StartsWith(sub + "."))
                        {
                            rel = "cecil\\" + sub + "\\" + rest.Substring(sub.Length + 1);
                            break;
                        }
                    }
                }
                string dest = System.IO.Path.Combine(EngineDir, rel);
                string dir = System.IO.Path.GetDirectoryName(dest);
                if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);
                if (System.IO.File.Exists(dest)) continue;   // 已存在不覆盖（保留状态与旧版一致性）
                using (var src = asm.GetManifestResourceStream(n))
                using (var dst = new System.IO.FileStream(dest, System.IO.FileMode.Create))
                {
                    src.CopyTo(dst);
                }
            }
            if (!any) throw new InvalidOperationException("内嵌引擎资源缺失（exe 损坏？）");
            if (!System.IO.File.Exists(System.IO.Path.Combine(EngineDir, "Patcher.ps1")))
                throw new InvalidOperationException("引擎核心 Patcher.ps1 释放失败");
        }
    }

    public partial class MainWindow : Window
    {
        static readonly Color CText = Color.FromRgb(0x3d, 0x44, 0x4d);
        static readonly Color CPlaceholder = Color.FromRgb(0xb3, 0xba, 0xc4);
        static readonly Color CMuted = Color.FromRgb(0x9a, 0xa3, 0xaf);
        static readonly Color COk = Color.FromRgb(0x16, 0xa3, 0x4a);
        static readonly Color CErr = Color.FromRgb(0xdc, 0x26, 0x26);
        static readonly Color CLog = Color.FromRgb(0x6b, 0x72, 0x80);
        static readonly Color CAccent = Color.FromRgb(0x3b, 0x82, 0xf6);
        static readonly Color CBorderGray = Color.FromRgb(0xcf, 0xd4, 0xda);

        readonly List<RadioRow> _radios = new List<RadioRow>();
        bool _placeholder = true;
        bool _chkChecked;
        bool _busy;

        TextBox _txtPath;
        TextBlock _lnkBrowse;
        System.Windows.Documents.Run _lnkClean;
        TextBlock _lblStatus;
        StackPanel _radioHost;
        StackPanel _logPanel;
        ScrollViewer _logScroll;
        Button _btnPatch;
        Button _btnLaunch;
        Button _btnUninstall;
        Grid _chkBackup;
        Border _chkBox;
        WpfPath _chkMark;

        // Patcher 通过读取这个固定路径的任务文件获得参数（用户选择写进此文件），
        // 然后把输出写进固定路径的 gui-out.log 供 exe 轮询显示。
        string Here()
        {
            return App.EngineDir;
        }

        static System.Windows.Media.SolidColorBrush B(string hex)
        {
            var b = new System.Windows.Media.SolidColorBrush(
                (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(hex));
            b.Freeze();
            return b;
        }

        static System.Windows.Media.SolidColorBrush B(System.Windows.Media.Color c)
        {
            var b = new System.Windows.Media.SolidColorBrush(c);
            b.Freeze();
            return b;
        }

        static System.Windows.Media.Color C(string hex)
        {
            return (System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(hex);
        }

        string TaskFile()
        {
            return System.IO.Path.Combine(Here(), "gui-task.json");
        }

        string OutLogFile()
        {
            return System.IO.Path.Combine(Here(), "gui-out.log");
        }

        string PatcherPath()
        {
            return System.IO.Path.Combine(Here(), "Patcher.ps1");
        }

        readonly string _presetPath;
        readonly bool _autoNone;

        public MainWindow(string presetPath, bool autoNone)
        {
            _presetPath = presetPath;
            _autoNone = autoNone;

            // 窗口/任务栏图标：exe 内嵌的 app.ico 资源提取
            try
            {
                var exePath = System.Reflection.Assembly.GetExecutingAssembly().Location;
                var ico = System.Drawing.Icon.ExtractAssociatedIcon(exePath);
                if (ico != null)
                {
                    using (var ms = new System.IO.MemoryStream())
                    {
                        ico.Save(ms);
                        ms.Position = 0;
                        Icon = System.Windows.Media.Imaging.BitmapFrame.Create(ms);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("图标加载失败: " + ex.Message);
            }

            BuildUi();
            BuildRadioRows();
            WireEvents();
        }

        void BuildUi()
        {
            Title = "PCL 下载补丁";
            Width = 940;
            Height = 720;
            MinWidth = 800;
            MinHeight = 620;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = B("#f7f8fa");
            FontFamily = new FontFamily("Microsoft YaHei UI");
            FontSize = 13;
            UseLayoutRounding = true;
            SnapsToDevicePixels = true;
            TextOptions.SetTextFormattingMode(this, TextFormattingMode.Display);
            TextOptions.SetTextRenderingMode(this, TextRenderingMode.ClearType);

            var root = new Grid { Margin = new Thickness(32, 22, 32, 26) };
            // 行 0-2 自适应内容；行 3（日志）占满剩余
            for (int i = 0; i < 4; i++)
            {
                var rd = new RowDefinition();
                if (i == 3) rd.Height = new GridLength(1, GridUnitType.Star);
                else rd.Height = GridLength.Auto;
                root.RowDefinitions.Add(rd);
            }

            var header = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 20) };
            var logoCanvas = new Canvas { Width = 52, Height = 52 };
            logoCanvas.Children.Add(new WpfPath
            {
                Data = Geometry.Parse("M 6,16 L 26,16 L 40,26 L 26,36 L 6,36 Z"),
                Stroke = B("#e3c68f"),
                StrokeThickness = 2.6,
                StrokeLineJoin = PenLineJoin.Round,
                StrokeStartLineCap = PenLineCap.Round,
                StrokeEndLineCap = PenLineCap.Round
            });
            header.Children.Add(logoCanvas);

            var titleStack = new StackPanel { Margin = new Thickness(16, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
            titleStack.Children.Add(new TextBlock { Text = "PCL 下载补丁", FontSize = 23, Foreground = B("#262b33") });
            titleStack.Children.Add(new TextBlock { Text = "恢复新版 PCL 被关闭的下载功能", FontSize = 13, Foreground = B("#8791a0"), Margin = new Thickness(0, 4, 0, 0) });
            titleStack.Children.Add(new TextBlock { Text = "by 沐序 · 启动器原作者 龙腾猫跃 LTCat", FontSize = 11.5, Foreground = B("#a8b0bb"), Margin = new Thickness(0, 3, 0, 0) });
            var repoLink = new TextBlock
            {
                Text = "github.com/AldricXZ/PCL-Download-Patch",
                FontSize = 11.5,
                Foreground = B("#a8b0bb"),
                Margin = new Thickness(0, 2, 0, 0),
                Cursor = Cursors.Hand,
                TextDecorations = TextDecorations.Underline
            };
            repoLink.MouseLeftButtonUp += delegate { OpenRepoLink(); };
            titleStack.Children.Add(repoLink);
            header.Children.Add(titleStack);
            root.Children.Add(header);
            Grid.SetRow(header, 0);

            var card = new Border
            {
                CornerRadius = new CornerRadius(14),
                Background = Brushes.White,
                BorderBrush = B("#eef0f3"),
                BorderThickness = new Thickness(1),
                Effect = new System.Windows.Media.Effects.DropShadowEffect
                {
                    Color = Color.FromRgb(0x23, 0x2d, 0x3c),
                    BlurRadius = 18,
                    ShadowDepth = 3,
                    Direction = 270,
                    Opacity = 0.10
                }
            };

            // 卡片内容：底层花纹 + 上层控件
            var cardGrid = new Grid();
            cardGrid.Children.Add(BuildFiligreeLayer());
            var cardInner = new StackPanel { Margin = new Thickness(24, 20, 24, 18) };

            cardInner.Children.Add(new TextBlock { Text = "启动器", FontSize = 15, Foreground = B("#30363f"), Margin = new Thickness(0, 0, 0, 10) });

            var pathRow = new Grid();
            pathRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            pathRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var pathBorder = new Border
            {
                Height = 40,
                CornerRadius = new CornerRadius(8),
                Background = B("#fbfbfc"),
                BorderBrush = B("#e3e6ea"),
                BorderThickness = new Thickness(1),
                Padding = new Thickness(12, 0, 12, 0),
                Margin = new Thickness(0, 0, 14, 0)
            };
            _txtPath = new TextBox
            {
                FontSize = 13,
                BorderThickness = new Thickness(0),
                Background = Brushes.Transparent,
                Foreground = B(CPlaceholder),
                VerticalContentAlignment = VerticalAlignment.Center,
                Text = "把 Plain Craft Launcher 2.exe 拖到这里，或点右侧浏览",
                AllowDrop = true
            };
            pathBorder.Child = _txtPath;
            pathRow.Children.Add(pathBorder);

            var browse = new TextBlock { Text = "浏览…", Foreground = B("#5b87c7"), FontSize = 13.5, VerticalAlignment = VerticalAlignment.Center, Cursor = Cursors.Hand };
            browse.MouseLeftButtonUp += delegate { BrowseFile(); };
            _lnkBrowse = browse;
            Grid.SetColumn(browse, 1);
            pathRow.Children.Add(browse);
            cardInner.Children.Add(pathRow);

            cardInner.Children.Add(new TextBlock { Text = "更新后如何自动恢复补丁", Foreground = B("#5b6470"), FontSize = 13, Margin = new Thickness(0, 14, 0, 8) });

            _radioHost = new StackPanel();
            cardInner.Children.Add(_radioHost);

            _chkBackup = new Grid { Margin = new Thickness(0, 7, 0, 0), Cursor = Cursors.Hand, Background = Brushes.Transparent };
            _chkBackup.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            _chkBackup.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var chkHost = new Grid { Width = 14, Height = 14, VerticalAlignment = VerticalAlignment.Center };
            _chkBox = new Border { CornerRadius = new CornerRadius(4), BorderThickness = new Thickness(1.4), BorderBrush = B("#cfd4da"), Background = Brushes.Transparent };
            _chkMark = new WpfPath
            {
                Data = Geometry.Parse("M 2.5,7 L 5.5,10.5 L 11.5,3"),
                Stroke = B("#3b82f6"),
                StrokeThickness = 2,
                StrokeStartLineCap = PenLineCap.Round,
                StrokeEndLineCap = PenLineCap.Round,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Visibility = Visibility.Collapsed
            };
            chkHost.Children.Add(_chkBox);
            chkHost.Children.Add(_chkMark);
            _chkBackup.Children.Add(chkHost);
            Grid.SetColumn(chkHost, 0);

            var chkText = new TextBlock { Text = "打补丁前复制一份备份到同目录", Foreground = B("#6b7280"), FontSize = 13, Margin = new Thickness(9, 0, 0, 0), VerticalAlignment = VerticalAlignment.Center };
            _chkBackup.Children.Add(chkText);
            Grid.SetColumn(chkText, 1);
            cardInner.Children.Add(_chkBackup);

            var hint = new TextBlock { FontSize = 12, Foreground = B("#a8b0bb"), Margin = new Thickness(0, 8, 0, 0), TextWrapping = TextWrapping.Wrap };
            hint.Inlines.Add(new Run("补丁会自动在包内保留原始 exe（约 6MB），用于「卸载补丁」完整还原 · "));
            _lnkClean = new Run("清理原始备份") { Foreground = B("#6f9ad4"), Cursor = Cursors.Hand, TextDecorations = TextDecorations.Underline };
            hint.Inlines.Add(_lnkClean);
            cardInner.Children.Add(hint);

            cardGrid.Children.Add(cardInner);
            card.Child = cardGrid;
            root.Children.Add(card);
            Grid.SetRow(card, 1);

            var btnRow = new Grid { Margin = new Thickness(0, 22, 0, 0) };
            var btnStack = new StackPanel { Orientation = Orientation.Horizontal };

            _btnPatch = MakeButton("开始打补丁", B("#3b82f6"), Brushes.White, null, 132);
            _btnPatch.Click += delegate { DoPatch(); };
            btnStack.Children.Add(_btnPatch);

            _btnLaunch = MakeButton("启动PCL", Brushes.White, B("#3d444d"), B("#e3e6ea"), 116);
            _btnLaunch.Margin = new Thickness(12, 0, 0, 0);
            _btnLaunch.Click += delegate { DoLaunch(); };
            btnStack.Children.Add(_btnLaunch);

            _btnUninstall = MakeButton("卸载补丁", Brushes.White, B("#b0413a"), B("#f0d9d7"), 116);
            _btnUninstall.Margin = new Thickness(12, 0, 0, 0);
            _btnUninstall.Click += delegate { DoUninstall(); };
            btnStack.Children.Add(_btnUninstall);

            btnRow.Children.Add(btnStack);

            _lblStatus = new TextBlock { Text = "就绪", Foreground = B("#9aa3af"), FontSize = 12.5, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Center };
            btnRow.Children.Add(_lblStatus);
            root.Children.Add(btnRow);
            Grid.SetRow(btnRow, 2);

            var logBorder = new Border
            {
                CornerRadius = new CornerRadius(10),
                Background = Brushes.White,
                BorderBrush = B("#eef0f3"),
                BorderThickness = new Thickness(1),
                Margin = new Thickness(0, 16, 0, 0),
                Padding = new Thickness(18, 14, 18, 14),
                MinHeight = 190
            };
            _logPanel = new StackPanel();
            _logScroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, Content = _logPanel };
            logBorder.Child = _logScroll;
            root.Children.Add(logBorder);
            Grid.SetRow(logBorder, 3);

            Content = root;

            AllowDrop = true;
            DragOver += delegate(object s, DragEventArgs e) { HandleDragOver(e); };
            Drop += delegate(object s, DragEventArgs e) { HandleDrop(e); };
            _txtPath.DragOver += delegate(object s, DragEventArgs e) { HandleDragOver(e); };
            _txtPath.Drop += delegate(object s, DragEventArgs e) { HandleDrop(e); };

            _txtPath.GotFocus += delegate
            {
                if (_placeholder)
                {
                    _txtPath.Text = string.Empty;
                    _txtPath.Foreground = B(CText);
                    _placeholder = false;
                }
            };
            _txtPath.LostFocus += delegate
            {
                if (string.IsNullOrWhiteSpace(_txtPath.Text))
                {
                    _txtPath.Foreground = B(CPlaceholder);
                    _txtPath.Text = "把 Plain Craft Launcher 2.exe 拖到这里，或点右侧浏览";
                    _placeholder = true;
                }
            };

            Loaded += delegate
            {
                AppendLog("就绪。选择启动器 exe 后点「开始打补丁」。", CMuted);
                // 命令行预填（bat 拖入路径），常规版 bat 再自动开打
                if (!string.IsNullOrEmpty(_presetPath)) SetExePath(_presetPath);
                if (_autoNone)
                {
                    if (_radios.Count > 2) _radios[2].SetChecked(true);
                    if (HasValidPath()) DoPatch();
                }
                RefreshState();
            };
        }

        /// <summary>淡金卷草纹：坐标与 HTML 预览稿的 SVG 路径一致</summary>
        FrameworkElement BuildFiligreeLayer()
        {
            var viewbox = new Viewbox
            {
                Width = 132,
                Height = 132,
                Stretch = Stretch.Uniform,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Bottom,
                Margin = new Thickness(0, 0, 16, 12),
                IsHitTestVisible = false
            };

            var canvas = new Canvas { Width = 200, Height = 200 };

            var grad = new LinearGradientBrush { StartPoint = new Point(0, 1), EndPoint = new Point(1, 0) };
            grad.GradientStops.Add(new GradientStop(C("#b8894c"), 0));
            grad.GradientStops.Add(new GradientStop(C("#d0a869"), 0.55));
            grad.GradientStops.Add(new GradientStop(C("#e3c68f"), 1));
            grad.Freeze();
            grad.Freeze();

            // 藤蔓线条（透明度 0.10）
            var strokeGroup = new Canvas { Opacity = 0.10 };
            string[] strokes = new string[]
            {
                "M26 168 C 8 150, 10 118, 34 106 C 56 95, 78 105, 80 124 C 82 141, 66 152, 55 145 C 46 139, 47 127, 56 125",
                "M34 106 C 62 86, 92 72, 122 58 C 144 48, 162 36, 172 22",
                "M172 22 C 182 8, 197 12, 198 25 C 199 36, 188 42, 181 36",
                "M122 58 C 116 80, 118 102, 132 114 C 142 123, 156 120, 157 109 C 158 100, 148 96, 143 102",
                "M92 72 C 88 54, 92 38, 102 28",
                "M62 86 C 54 70, 52 54, 58 42"
            };
            for (int i = 0; i < strokes.Length; i++)
            {
                strokeGroup.Children.Add(new WpfPath
                {
                    Data = Geometry.Parse(strokes[i]),
                    Stroke = grad,
                    StrokeThickness = (i >= 4) ? 1.5 : 2.1,
                    StrokeStartLineCap = PenLineCap.Round,
                    StrokeEndLineCap = PenLineCap.Round,
                    StrokeLineJoin = PenLineJoin.Round
                });
            }
            canvas.Children.Add(strokeGroup);

            // 叶片（透明度 0.075）
            var leafGroup = new Canvas { Opacity = 0.075 };
            string[] leaves = new string[]
            {
                "M102 28 C 106 14, 118 6, 128 8 C 124 22, 114 30, 102 28 Z",
                "M58 42 C 52 28, 56 14, 66 10 C 70 24, 66 38, 58 42 Z",
                "M144 48 C 152 34, 166 28, 176 32 C 168 46, 156 52, 144 48 Z",
                "M80 124 C 68 118, 62 106, 66 96 C 78 102, 84 114, 80 124 Z",
                "M132 114 C 142 122, 146 134, 141 143 C 130 136, 126 124, 132 114 Z"
            };
            foreach (var d in leaves)
            {
                leafGroup.Children.Add(new WpfPath { Data = Geometry.Parse(d), Fill = grad });
            }
            canvas.Children.Add(leafGroup);

            // 三瓣小花（透明度 0.085）
            var flowerGroup = new Canvas { Opacity = 0.085 };
            AddFlower(flowerGroup, 66, 10, 0.62, grad);
            AddFlower(flowerGroup, 181, 36, 0.5, grad);
            canvas.Children.Add(flowerGroup);

            viewbox.Child = canvas;
            return viewbox;
        }

        void AddFlower(Canvas parent, double cx, double cy, double scale, Brush fill)
        {
            for (int i = 0; i < 3; i++)
            {
                var petal = new Ellipse { Width = 18, Height = 26, Fill = fill };
                var tg = new TransformGroup();
                tg.Children.Add(new RotateTransform(i * 120));
                tg.Children.Add(new ScaleTransform(scale, scale));
                tg.Children.Add(new TranslateTransform(cx, cy));
                petal.RenderTransform = tg;
                Canvas.SetLeft(petal, -9);
                Canvas.SetTop(petal, -13);
                parent.Children.Add(petal);
            }
        }

        Button MakeButton(string text, Brush bg, Brush fg, Brush border, double width)
        {
            var b = new Button
            {
                Content = text,
                Width = width,
                Height = 38,
                Background = bg,
                Foreground = fg,
                FontSize = 13.5,
                Cursor = Cursors.Hand,
                BorderThickness = border == null ? new Thickness(0) : new Thickness(1),
                BorderBrush = border ?? Brushes.Transparent
            };
            var template = new ControlTemplate(typeof(Button));
            var borderFactory = new FrameworkElementFactory(typeof(Border));
            borderFactory.SetValue(Border.CornerRadiusProperty, new CornerRadius(8));
            borderFactory.SetValue(Border.BackgroundProperty, new TemplateBindingExtension(Button.BackgroundProperty));
            borderFactory.SetValue(Border.BorderBrushProperty, new TemplateBindingExtension(Button.BorderBrushProperty));
            borderFactory.SetValue(Border.BorderThicknessProperty, new TemplateBindingExtension(Button.BorderThicknessProperty));
            var cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            borderFactory.AppendChild(cp);
            template.VisualTree = borderFactory;
            b.Template = template;
            return b;
        }

        void WireEvents()
        {
            // 拖放（窗口级）
            AllowDrop = true;
            DragOver += delegate(object s, DragEventArgs e) { HandleDragOver(e); };
            Drop += delegate(object s, DragEventArgs e) { HandleDrop(e); };

            // 浏览链接
            _lnkBrowse.MouseLeftButtonUp += delegate { BrowseFile(); };

            // 清理原始备份链接
            _lnkClean.MouseLeftButtonUp += delegate { CleanPristine(); };

            // 备份勾选切换
            _chkBackup.MouseLeftButtonUp += delegate
            {
                _chkChecked = !_chkChecked;
                _chkMark.Visibility = _chkChecked ? Visibility.Visible : Visibility.Collapsed;
                _chkBox.BorderBrush = new SolidColorBrush(_chkChecked ? CAccent : CBorderGray);
            };
        }

        void BuildRadioRows()
        {
            _radios.Add(new RadioRow("常驻守护（推荐）", "开机自启后台，打开启动器时检测、关闭后自动修复", true));
            _radios.Add(new RadioRow("启动壳检测", "无后台；日常用「启动PCL」按钮打开启动器", false));
            _radios.Add(new RadioRow("不自动修复", "更新后把新 exe 再拖一次", false));

            for (int i = 0; i < _radios.Count; i++)
            {
                RadioRow r = _radios[i];
                r.Margin = new Thickness(0, 0, 0, 9);
                _radioHost.Children.Add(r);
            }
            for (int i = 0; i < _radios.Count; i++)
            {
                RadioRow self = _radios[i];
                self.MouseLeftButtonUp += delegate
                {
                    for (int j = 0; j < _radios.Count; j++)
                    {
                        _radios[j].SetChecked(ReferenceEquals(_radios[j], self));
                    }
                };
            }
        }

        void OpenRepoLink()
        {
            // 固定 https 地址 + 固定域名；经 WScript.Shell COM 打开（与其他调用同通道）
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                dynamic shell = Activator.CreateInstance(shellType);
                shell.Run("https://github.com/AldricXZ/PCL-Download-Patch", 0, false);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("打开链接失败: " + ex.Message);
            }
        }

        void HandleDragOver(DragEventArgs e)
        {
            if (e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effects = DragDropEffects.Copy;
            e.Handled = true;
        }

        void HandleDrop(DragEventArgs e)
        {
            try
            {
                string[] files = e.Data.GetData(DataFormats.FileDrop) as string[];
                if (files != null && files.Length > 0) SetExePath(files[0]);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("拖放失败: " + ex.Message);
            }
        }

        void SetExePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path)) return;
            path = path.Trim('"');
            if (!File.Exists(path)) return;
            if (!path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) return;
            _placeholder = false;
            _txtPath.Text = path;
            _txtPath.Foreground = B(CText);
        }

        void BrowseFile()
        {
            var dlg = new Microsoft.Win32.OpenFileDialog();
            dlg.Filter = "启动器 (*.exe)|*.exe";
            dlg.Title = "选择 Plain Craft Launcher 2.exe";
            if (dlg.ShowDialog() == true) SetExePath(dlg.FileName);
        }

        void AppendLog(string text, Color color)
        {
            var tb = new TextBlock
            {
                Text = text,
                Foreground = B(color),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 12.5,
                Margin = new Thickness(0, 0, 0, 5),
                TextWrapping = TextWrapping.Wrap
            };
            _logPanel.Children.Add(tb);
            _logScroll.UpdateLayout();
            _logScroll.ScrollToEnd();
        }

        void SetBusy(bool on)
        {
            _busy = on;
            _btnPatch.IsEnabled = !on;
            _btnLaunch.IsEnabled = !on;
            _btnUninstall.IsEnabled = !on;
            Cursor = on ? Cursors.Wait : Cursors.Arrow;
        }

        bool HasValidPath()
        {
            if (_placeholder) return false;
            if (string.IsNullOrWhiteSpace(_txtPath.Text)) return false;
            return File.Exists(_txtPath.Text);
        }

        string CurrentMode()
        {
            if (_radios[1].Checked) return "shell";
            if (_radios[2].Checked) return "none";
            return "watch";
        }

        // ============================ 与 Patcher 的通信 ============================
        // exe 把用户选择写入固定路径的 gui-task.json（仅数据，无命令），
        // 然后通过 WScript.Shell 执行一条完全固定的命令行（不含任何变量拼接）：
        //   powershell -NoProfile -ExecutionPolicy Bypass -File Patcher.ps1 -GuiTask
        // Patcher 自己读 gui-task.json、执行对应操作、把输出写进 gui-out.log，exe 轮询显示。

        void WriteTask(string action)
        {
            var sb = new StringBuilder();
            sb.Append("{\n");
            sb.Append("  \"action\": \"").Append(action).Append("\",\n");
            sb.Append("  \"exePath\": \"").Append(EscapeJson(HasValidPath() ? _txtPath.Text : "")).Append("\",\n");
            sb.Append("  \"backup\": \"").Append(_chkChecked ? "1" : "0").Append("\",\n");
            sb.Append("  \"mode\": \"").Append(CurrentMode()).Append("\"\n");
            sb.Append("}\n");
            File.WriteAllText(TaskFile(), sb.ToString(), new UTF8Encoding(false));
        }

        static string EscapeJson(string s)
        {
            if (string.IsNullOrEmpty(s)) return string.Empty;
            return s.Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        /// <summary>固定命令行，零变量拼接：安全工具可完整审阅</summary>
        void RunFixedCommand()
        {
            string patcher = PatcherPath();
            if (!File.Exists(patcher)) throw new FileNotFoundException("Patcher.ps1 不存在", patcher);

            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) throw new InvalidOperationException("WScript.Shell 组件不可用");
            dynamic shell = Activator.CreateInstance(shellType);
            shell.CurrentDirectory = Here();

            // 唯一被执行的命令行，恒为该字符串
            string fixedCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File Patcher.ps1 -GuiTask";
            shell.Run(fixedCommand, 0, true);
        }

        void ReadOutLog()
        {
            string logFile = OutLogFile();
            if (!File.Exists(logFile)) return;
            foreach (string line in File.ReadAllLines(logFile, Encoding.UTF8))
            {
                if (line.Contains("成功")) AppendLog(line, COk);
                else if (line.Contains("失败")) AppendLog(line, CErr);
                else if (line.Trim().Length > 0) AppendLog(line, CLog);
            }
        }

        string ReadOutLogText()
        {
            string logFile = OutLogFile();
            return File.Exists(logFile)
                ? File.ReadAllText(logFile, Encoding.UTF8)
                : string.Empty;
        }

        void DoPatch()
        {
            if (_busy) return;
            if (!HasValidPath())
            {
                MessageBox.Show("请先选择 Plain Craft Launcher 2.exe。", "PCL 下载补丁",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            SetBusy(true);
            _logPanel.Children.Clear();
            _lblStatus.Text = "正在打补丁…";
            try
            {
                WriteTask("patch");
                RunFixedCommand();
                ReadOutLog();

                string all = ReadOutLogText();
                if (all.Contains("完成"))
                {
                    _lblStatus.Text = "补丁完成";
                    AppendLog(string.Empty, CMuted);
                    AppendLog("√ 补丁完成，可以启动启动器了。", COk);
                }
                else
                {
                    _lblStatus.Text = "补丁失败";
                    AppendLog(string.Empty, CMuted);
                    AppendLog("× 补丁失败，原文件未被改动。", CErr);
                }
            }
            catch (Exception ex)
            {
                _lblStatus.Text = "补丁失败";
                AppendLog("错误：" + ex.Message, CErr);
            }
            finally
            {
                SetBusy(false);
                RefreshState();
            }
        }

        void DoUninstall()
        {
            if (_busy) return;

            var r = MessageBox.Show(
                "将把启动器还原到打补丁前的状态，并移除开机自启守护。\n\n确定要卸载补丁吗？",
                "卸载补丁", MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (r != MessageBoxResult.Yes) return;

            SetBusy(true);
            _logPanel.Children.Clear();
            _lblStatus.Text = "正在卸载…";
            try
            {
                WriteTask("uninstall");
                RunFixedCommand();
                ReadOutLog();

                string all = ReadOutLogText();
                if (all.Contains("卸载完成"))
                {
                    _lblStatus.Text = "已卸载";
                    AppendLog(string.Empty, CMuted);
                    AppendLog("√ 卸载完成，启动器已还原。", COk);
                }
                else if (all.Contains("未找到原始备份"))
                {
                    _lblStatus.Text = "无法卸载";
                    MessageBox.Show(
                        "未找到原始备份，无法自动卸载。\n\n请从官方渠道重新下载启动器覆盖。",
                        "卸载补丁", MessageBoxButton.OK, MessageBoxImage.Warning);
                }
                else
                {
                    _lblStatus.Text = "卸载失败";
                }
            }
            finally
            {
                SetBusy(false);
                RefreshState();
            }
        }

        void CleanPristine()
        {
            var r = MessageBox.Show(
                "删除后「卸载补丁」将无法使用，只能从官方重新下载启动器覆盖。\n\n确定要清理原始备份吗？",
                "清理原始备份", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (r != MessageBoxResult.Yes) return;

            try
            {
                WriteTask("clean");
                RunFixedCommand();
                ReadOutLog();
                AppendLog("已清理原始备份。", CMuted);
                RefreshState();
            }
            catch (Exception ex)
            {
                MessageBox.Show("清理失败：" + ex.Message, "清理原始备份",
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        void DoLaunch()
        {
            if (_busy) return;
            SetBusy(true);
            try
            {
                WriteTask("launch");
                RunFixedCommand();
                ReadOutLog();
            }
            finally
            {
                SetBusy(false);
            }
        }

        void RefreshState()
        {
            try
            {
                WriteTask("status");
                RunFixedCommand();
                string json = ReadOutLogText();
                bool pristine = json.Contains("\"PristineAvailable\":true");
                _btnUninstall.IsEnabled = pristine;
                // Run 无 Visibility；用颜色和删除线表达可用性
                _lnkClean.Foreground = new SolidColorBrush(pristine
                    ? Color.FromRgb(0x6f, 0x9a, 0xd4)
                    : Color.FromRgb(0xc5, 0xc9, 0xcf));
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine("状态读取失败: " + ex.Message);
            }
        }
    }

    /// <summary>单选行：圆环 + 主文 + 提示文</summary>
    public class RadioRow : Grid
    {
        public bool Checked { get; private set; }
        readonly Ellipse _ring;
        readonly Ellipse _dot;

        public RadioRow(string main, string hint, bool isChecked)
        {
            Background = Brushes.Transparent;
            Cursor = Cursors.Hand;
            Height = 22;

            ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var host = new Grid { Width = 15, Height = 15, VerticalAlignment = VerticalAlignment.Center };

            _ring = new Ellipse
            {
                Width = 15,
                Height = 15,
                StrokeThickness = 1.6,
                Stroke = new SolidColorBrush(Color.FromRgb(0xd3, 0xd7, 0xdd)),
                Fill = Brushes.Transparent
            };

            _dot = new Ellipse
            {
                Width = 7,
                Height = 7,
                Fill = new SolidColorBrush(Color.FromRgb(0x3b, 0x82, 0xf6)),
                Visibility = Visibility.Collapsed
            };

            host.Children.Add(_ring);
            host.Children.Add(_dot);
            Children.Add(host);
            SetColumn(host, 0);

            var mainTb = new TextBlock
            {
                Text = main,
                FontSize = 13.5,
                Foreground = new SolidColorBrush(Color.FromRgb(0x3d, 0x44, 0x4d)),
                Margin = new Thickness(9, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center
            };
            Children.Add(mainTb);
            SetColumn(mainTb, 1);

            var hintTb = new TextBlock
            {
                Text = "— " + hint,
                FontSize = 12,
                Foreground = new SolidColorBrush(Color.FromRgb(0x9a, 0xa3, 0xaf)),
                Margin = new Thickness(12, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center
            };
            Children.Add(hintTb);
            SetColumn(hintTb, 2);

            SetChecked(isChecked);
        }

        public void SetChecked(bool value)
        {
            Checked = value;
            _ring.Stroke = new SolidColorBrush(value
                ? Color.FromRgb(0x3b, 0x82, 0xf6)
                : Color.FromRgb(0xd3, 0xd7, 0xdd));
            _dot.Visibility = value ? Visibility.Visible : Visibility.Collapsed;
        }
    }
}
