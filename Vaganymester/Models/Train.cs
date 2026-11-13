using System.Windows.Media;

namespace Vaganymester.Models;

public enum TrainType { Szemely, InterCity, Teher }

public sealed class Train : BindableBase
{
    public const double Length = 76;

    public string Number { get; }
    public string Destination { get; }
    public TrainType Type { get; }
    public Driver Driver { get; }
    public int Direction { get; }
    public double MaxSpeed { get; }
    public string KindText => Type switch
    {
        TrainType.InterCity => "InterCity",
        TrainType.Teher => "Tehervonat",
        _ => "Személyvonat"
    };
    public string DirectionText => Direction > 0 ? "Nyugat → Kelet" : "Kelet → Nyugat";
    public Brush BodyBrush => Type switch
    {
        TrainType.InterCity => Brushes.Goldenrod,
        TrainType.Teher => Brushes.SteelBlue,
        _ => Brushes.MediumTurquoise
    };
    public string DriverName => Driver.Name;

    private double _x;
    public double X { get => _x; set => Set(ref _x, value); }

    private double _speed;
    public double Speed
    {
        get => _speed;
        set
        {
            if (!Set(ref _speed, value)) return;
            Raise(nameof(SpeedLabel));
        }
    }

    private int _track = -1;
    public int Track
    {
        get => _track;
        set
        {
            if (!Set(ref _track, value)) return;
            Raise(nameof(TrackLabel));
        }
    }

    private string _status = "Bejelentkezett";
    public string Status { get => _status; set => Set(ref _status, value); }

    private bool _manualHold;
    public bool ManualHold { get => _manualHold; set => Set(ref _manualHold, value); }

    private bool _emergency;
    public bool Emergency { get => _emergency; set => Set(ref _emergency, value); }

    private bool _ignoreNextRed;
    public bool IgnoreNextRed { get => _ignoreNextRed; set => Set(ref _ignoreNextRed, value); }

    private bool _crashed;
    public bool Crashed { get => _crashed; set => Set(ref _crashed, value); }

    public string? PendingSection { get; set; }
    public string SpeedLabel => $"{Math.Round(Speed * 1.1):0} km/h";
    public string TrackLabel => Track < 0 ? "Nyílt vonal" : $"{Track + 1}. vágány";

    private double _canvasLeft;
    public double CanvasLeft { get => _canvasLeft; private set => Set(ref _canvasLeft, value); }

    private double _canvasTop;
    public double CanvasTop { get => _canvasTop; private set => Set(ref _canvasTop, value); }

    public double CenterY { get; private set; }

    public Train(string number, string destination, TrainType type, Driver driver, int direction, double x)
    {
        Number = number;
        Destination = destination;
        Type = type;
        Driver = driver;
        Direction = direction;
        X = x;
        MaxSpeed = type switch
        {
            TrainType.InterCity => 100,
            TrainType.Teher => 65,
            _ => 82
        };
        UpdateLayout();
    }

    public void UpdateLayout()
    {
        // A 2. vágány két kitérőn, folytonos ívvel kapcsolódik a fővágányhoz.
        double y = 195;
        if (Track == 1)
        {
            if (X < 325 || X > 830) y = 195;
            else if (X < 415) y = 195 + (X - 325) / 90.0 * 123;
            else if (X <= 740) y = 318;
            else y = 318 - (X - 740) / 90.0 * 123;
        }

        CenterY = y;
        CanvasLeft = Direction > 0 ? X - Length : X;
        CanvasTop = y - 18;
    }
}
