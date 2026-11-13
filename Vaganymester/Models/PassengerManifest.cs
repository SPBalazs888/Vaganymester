using System.Collections.ObjectModel;

namespace Vaganymester.Models;

/// <summary>A kijelzett nevek és jegyek kizárólag generált szimulációs adatok.</summary>
public sealed record Passenger(string Name, string From, string To, string Ticket);

public sealed class TrainSeat : BindableBase
{
    public int Row { get; }
    public string Letter { get; }
    public string Label => $"{Row}{Letter}";
    public string Description => Passenger is null ? $"{Label} – szabad hely" : $"{Label} – {Passenger.Name}";
    public string ShortName => Passenger is null ? "Szabad" : Passenger.Name.Split(' ').Last();
    public bool IsOccupied => Passenger is not null;

    private Passenger? _passenger;
    public Passenger? Passenger
    {
        get => _passenger;
        internal set
        {
            if (!Set(ref _passenger, value)) return;
            Raise(nameof(IsOccupied));
            Raise(nameof(Description));
            Raise(nameof(ShortName));
        }
    }

    public TrainSeat(int row, string letter) { Row = row; Letter = letter; }
}

public sealed class TrainSeatRow
{
    public int Number { get; }
    public TrainSeat A { get; }
    public TrainSeat B { get; }
    public TrainSeat C { get; }
    public TrainSeat D { get; }
    public TrainSeatRow(int number)
    {
        Number = number;
        A = new TrainSeat(number, "A"); B = new TrainSeat(number, "B");
        C = new TrainSeat(number, "C"); D = new TrainSeat(number, "D");
    }
}

public sealed class TrainCarriage : BindableBase
{
    private readonly Train _train;
    public int Number { get; }
    public string Name => $"{Number}. kocsi";
    public string Category { get; }
    public ObservableCollection<TrainSeatRow> Rows { get; } = new();
    public ObservableCollection<TrainSeat> Manifest { get; } = new();
    public IEnumerable<TrainSeat> Seats => Rows.SelectMany(r => new[] { r.A, r.B, r.C, r.D });
    public int Capacity => Rows.Count * 4;
    public int Occupied => Manifest.Count;
    public int Free => Capacity - Occupied;
    public string Summary => $"{Occupied}/{Capacity} foglalt • {Free} szabad";

    public TrainCarriage(Train train, int number, string category, int rowCount)
    {
        _train = train;
        Number = number;
        Category = category;
        for (int i = 1; i <= rowCount; i++) Rows.Add(new TrainSeatRow(i));
    }

    public bool Assign(TrainSeat seat, Passenger? passenger)
    {
        if (!Seats.Contains(seat)) return false;
        seat.Passenger = passenger;
        Manifest.Clear();
        foreach (var occupied in Seats.Where(s => s.IsOccupied)) Manifest.Add(occupied);
        Raise(nameof(Occupied)); Raise(nameof(Free)); Raise(nameof(Summary));
        _train.NotifyPassengerChanged();
        return true;
    }
}

public static class PassengerManifestFactory
{
    private static readonly string[] Surnames =
    {
        "Kovács", "Nagy", "Szabó", "Tóth", "Horváth", "Varga", "Kiss", "Molnár", "Németh", "Farkas",
        "Balogh", "Papp", "Takács", "Juhász", "Lakatos", "Mészáros", "Oláh", "Simon", "Rácz", "Fekete"
    };
    private static readonly string[] FirstNames =
    {
        "Anna", "Péter", "Eszter", "Gábor", "Réka", "Máté", "Lili", "Dávid", "Zsófia", "Bence",
        "Dóra", "Ádám", "Luca", "Balázs", "Noémi", "Levente", "Petra", "Márk", "Kata", "Zoltán"
    };
    private static readonly string[] Tickets = { "Teljes árú", "Diák", "Nyugdíjas", "Kedvezményes" };

    public static void Populate(Train train)
    {
        if (train.Type == TrainType.Teher) return;
        int seed = 17;
        foreach (char c in train.Number) seed = unchecked(seed * 31 + c);
        var random = new Random(seed);
        int carriageCount = train.Type == TrainType.InterCity ? 4 : 3;
        int rowCount = train.Type == TrainType.InterCity ? 10 : 8;
        int passengerNo = 0;
        for (int coach = 1; coach <= carriageCount; coach++)
        {
            var carriage = new TrainCarriage(train, coach,
                train.Type == TrainType.InterCity && coach == 1 ? "1. osztály" : "2. osztály", rowCount);
            train.Carriages.Add(carriage);
            foreach (TrainSeat seat in carriage.Seats)
            {
                if (random.NextDouble() > (train.Type == TrainType.InterCity ? 0.73 : 0.62)) continue;
                int id = passengerNo++;
                string name = $"{Surnames[(id * 7 + random.Next(20)) % Surnames.Length]} " +
                              FirstNames[(id * 11 + random.Next(20)) % FirstNames.Length];
                string origin = train.Direction > 0 ? "Nyugati végállomás" : "Keleti végállomás";
                carriage.Assign(seat, new Passenger(name, origin, train.Destination, Tickets[random.Next(Tickets.Length)]));
            }
        }
        train.NotifyPassengerChanged();
    }
}
