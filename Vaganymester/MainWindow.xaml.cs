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
    private readonly DispatcherTimer _timer;
    private readonly Dictionary<Train, TrainDetailsWindow> _detailsWindows = new();
    private DateTime _previousTick = DateTime.UtcNow;

    public MainWindow()
    {
        InitializeComponent();
        DataContext = Engine;

        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(40) };
        _timer.Tick += (_, _) =>
        {
            DateTime now = DateTime.UtcNow;
            double dt = Math.Clamp((now - _previousTick).TotalSeconds, 0, 0.10);
            _previousTick = now;
            Engine.Tick(dt);
        };
        Engine.Trains.CollectionChanged += (_, e) =>
        {
            if (e.OldItems is null) return;
            foreach (Train oldTrain in e.OldItems)
                if (_detailsWindows.TryGetValue(oldTrain, out var window)) window.Close();
        };
        _timer.Start();
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
        Engine.Step();
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
                Engine.Step();
                e.Handled = true;
                break;
            case Key.F9:
                ResetSimulation();
                e.Handled = true;
                break;
        }
    }
}
