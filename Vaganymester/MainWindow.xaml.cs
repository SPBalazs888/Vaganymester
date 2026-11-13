using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Vaganymester.Models;
using Vaganymester.Simulation;

namespace Vaganymester;

public partial class MainWindow : Window
{
    public DispatchEngine Engine { get; } = new();
    public ObservableCollection<string> NeighborMessages { get; } = new();
    private readonly DispatcherTimer _timer;
    private readonly Dictionary<Train, TrainDetailsWindow> _detailsWindows = new();
    private DateTime _previousTick = DateTime.UtcNow;
    private bool _isFullScreen;
    private Rect _previousWindowBounds;
    private NeighborCommunicationWindow? _neighborWindow;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = Engine;
        _previousWindowBounds = new Rect(Left, Top, Width, Height);
        NeighborMessages.Add("Állomásközi üzenetek: a szomszédos állomások elérhetők.");
        AddNeighborCommunicationButton();

        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(40) };
        _timer.Tick += (_, _) =>
        {
            DateTime now = DateTime.UtcNow;
            double dt = Math.Clamp((now - _previousTick).TotalSeconds, 0, 0.10);
            _previousTick = now;
            AdvanceSimulation(() => Engine.Tick(dt));
        };
        Engine.Trains.CollectionChanged += (_, e) =>
        {
            if (e.OldItems is null) return;
            foreach (Train oldTrain in e.OldItems)
                if (_detailsWindows.TryGetValue(oldTrain, out var window)) window.Close();
        };
        _timer.Start();
    }

    private void AddNeighborCommunicationButton()
    {
        if (Content is not Grid root) return;
        var header = root.Children.OfType<Grid>().FirstOrDefault(grid => Grid.GetRow(grid) == 0);
        var controls = header?.Children.OfType<StackPanel>()
            .FirstOrDefault(panel => Grid.GetColumn(panel) == 1);
        if (controls == null) return;

        var button = new Button
        {
            Content = "📨 Állomásközi üzenetek",
            Margin = new Thickness(0, 0, 8, 0),
            Padding = new Thickness(10, 5, 10, 5),
            ToolTip = "Üzenetek megtekintése és küldése a szomszédos állomásoknak"
        };
        button.Click += (_, _) => ShowNeighborCommunication();
        controls.Children.Insert(0, button);
    }

    private void ShowNeighborCommunication()
    {
        if (_neighborWindow is { IsVisible: true })
        {
            _neighborWindow.Activate();
            return;
        }

        _neighborWindow = new NeighborCommunicationWindow(NeighborMessages, AddNeighborMessage)
        {
            Owner = this
        };
        _neighborWindow.Closed += (_, _) => _neighborWindow = null;
        _neighborWindow.Show();
    }

    private void AddNeighborMessage(string message)
    {
        if (string.IsNullOrWhiteSpace(message)) return;
        NeighborMessages.Insert(0, $"{Engine.ClockText} — {message.Trim()}");
        while (NeighborMessages.Count > 100)
            NeighborMessages.RemoveAt(NeighborMessages.Count - 1);
    }

    private void AdvanceSimulation(Action advance)
    {
        var previousPositions = Engine.Trains.ToDictionary(train => train, train => train.X);
        advance();
        NotifyDepartures(previousPositions);
    }

    private void NotifyDepartures(IReadOnlyDictionary<Train, double> previousPositions)
    {
        foreach (var (train, oldX) in previousPositions)
        {
            if (!Engine.Trains.Contains(train) || train.Track < 0) continue;

            double exitSignalPosition = train.Direction > 0 ? 745 : 430;
            bool hasPassedExit = train.Direction > 0
                ? oldX < exitSignalPosition && train.X >= exitSignalPosition
                : oldX > exitSignalPosition && train.X <= exitSignalPosition;
            if (!hasPassedExit) continue;

            string direction = train.Direction > 0 ? "kelet" : "nyugat";
            AddNeighborMessage($"A(z) {train.Number} számú vonat elindult {direction} felé, a(z) {train.Track + 1}. vágányról.");
        }
    }

    private void ToggleFullScreen()
    {
        if (_isFullScreen)
        {
            WindowStyle = WindowStyle.SingleBorderWindow;
            ResizeMode = ResizeMode.CanResize;
            WindowState = WindowState.Normal;
            Left = _previousWindowBounds.Left;
            Top = _previousWindowBounds.Top;
            Width = _previousWindowBounds.Width;
            Height = _previousWindowBounds.Height;
            _isFullScreen = false;
            return;
        }

        _previousWindowBounds = new Rect(Left, Top, Width, Height);

        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        WindowState = WindowState.Maximized;
        _isFullScreen = true;
    }

    private void PlayPause_Click(object sender, RoutedEventArgs e) => Engine.IsRunning = !Engine.IsRunning;
    private void Reset_Click(object sender, RoutedEventArgs e) => ResetSimulation();

    private void ResetSimulation()
    {
        foreach (var window in _detailsWindows.Values.ToList()) window.Close();
        Engine.Reset();
    }
    private void Step_Click(object sender, RoutedEventArgs e)
    {
        Engine.IsRunning = false;
        AdvanceSimulation(Engine.Step);
    }

    private void Signal_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: Signal signal }) Engine.SelectedSignal = signal;
    }
    private void SignalGreen_Click(object sender, RoutedEventArgs e) => Engine.SetSignal(Engine.SelectedSignal, true);
    private void SignalRed_Click(object sender, RoutedEventArgs e) => Engine.SetSignal(Engine.SelectedSignal, false);

    private void Turnout_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: Turnout turnout })
        {
            Engine.SelectedTurnout = turnout;
            Engine.ToggleTurnout(turnout);
        }
    }
    private void ToggleTurnout_Click(object sender, RoutedEventArgs e) => Engine.ToggleTurnout(Engine.SelectedTurnout);

    private void Train_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: Train train })
        {
            Engine.SelectedTrain = train;
            ShowTrainDetails(train);
        }
    }
    private void TrainDetails_Click(object sender, RoutedEventArgs e)
    {
        if (Engine.SelectedTrain is Train train) ShowTrainDetails(train);
    }

    private void TrainList_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (Engine.SelectedTrain is Train train) ShowTrainDetails(train);
    }

    private void ShowTrainDetails(Train train)
    {
        if (_detailsWindows.TryGetValue(train, out var existing))
        {
            existing.Activate();
            return;
        }
        var window = new TrainDetailsWindow(train) { Owner = this };
        _detailsWindows.Add(train, window);
        window.Closed += (_, _) => _detailsWindows.Remove(train);
        window.Show();
    }

    private void ResumeTrain_Click(object sender, RoutedEventArgs e) => Engine.ResumeSelected();
    private void StopTrain_Click(object sender, RoutedEventArgs e) => Engine.StopSelected();
    private void EmergencyTrain_Click(object sender, RoutedEventArgs e) => Engine.EmergencySelected();
    private void ForcePass_Click(object sender, RoutedEventArgs e) => Engine.PassRedSelected();

    private void AddTrain_Click(object sender, RoutedEventArgs e)
    {
        int direction = DirectionPicker.SelectedIndex == 1 ? -1 : +1;
        TrainType type = TrainTypePicker.SelectedIndex switch
        {
            1 => TrainType.InterCity,
            2 => TrainType.Teher,
            _ => TrainType.Szemely
        };
        Engine.AddManualTrain(direction, type);
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        switch (e.Key)
        {
            case Key.Space:
                Engine.IsRunning = !Engine.IsRunning;
                e.Handled = true;
                break;
            case Key.F2:
                Engine.AddManualTrain(+1, TrainType.Szemely);
                e.Handled = true;
                break;
            case Key.F3:
                Engine.AddManualTrain(-1, TrainType.Szemely);
                e.Handled = true;
                break;
            case Key.F5:
                Engine.IsRunning = false;
                AdvanceSimulation(Engine.Step);
                e.Handled = true;
                break;
            case Key.F9:
                ResetSimulation();
                e.Handled = true;
                break;
            case Key.F11:
                ToggleFullScreen();
                e.Handled = true;
                break;
        }
    }
}
