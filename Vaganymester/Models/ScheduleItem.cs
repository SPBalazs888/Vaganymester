namespace Vaganymester.Models;

public sealed class ScheduleItem : BindableBase
{
    public string Number { get; }
    public int DueSecond { get; }
    public int Direction { get; }
    public TrainType Type { get; }
    public string Destination { get; }
    public Driver Driver { get; }
    public string DueTime => TimeSpan.FromHours(8).Add(TimeSpan.FromSeconds(DueSecond)).ToString(@"hh\:mm\:ss");
    public string Origin => Direction > 0 ? "Nyugat" : "Kelet";
    public bool Spawned { get; set; }

    private string _status = "Várható";
    public string Status { get => _status; set => Set(ref _status, value); }

    public ScheduleItem(string number, int dueSecond, int direction, TrainType type,
        string destination, Driver driver)
    {
        Number = number;
        DueSecond = dueSecond;
        Direction = direction;
        Type = type;
        Destination = destination;
        Driver = driver;
    }
}
