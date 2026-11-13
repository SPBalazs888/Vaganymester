using System.Collections.ObjectModel;
using System.Windows.Media;
using Vaganymester.Models;

namespace Vaganymester.Simulation;

/// <summary>
/// Egyszerűsített állomási biztosítóberendezés és folyamatos, időlépéses vonatszimuláció.
/// A valós vasúti biztosítóberendezést NEM helyettesíti.
/// </summary>
public sealed class DispatchEngine : BindableBase
{
    private const double WestPoint = 325;
    private const double EastPoint = 830;

    public ObservableCollection<Train> Trains { get; } = new();
    public ObservableCollection<Signal> Signals { get; } = new();
    public ObservableCollection<Turnout> Turnouts { get; } = new();
    public ObservableCollection<Driver> Drivers { get; } = new();
    public ObservableCollection<ScheduleItem> Timetable { get; } = new();
    public ObservableCollection<JournalEntry> Journal { get; } = new();

    public Turnout WestTurnout => Turnouts[0];
    public Turnout EastTurnout => Turnouts[1];

    private Train? _selectedTrain;
    public Train? SelectedTrain { get => _selectedTrain; set => Set(ref _selectedTrain, value); }

    private Signal? _selectedSignal;
    public Signal? SelectedSignal { get => _selectedSignal; set => Set(ref _selectedSignal, value); }

    private Turnout? _selectedTurnout;
    public Turnout? SelectedTurnout { get => _selectedTurnout; set => Set(ref _selectedTurnout, value); }

    private bool _isRunning = true;
    public bool IsRunning
    {
        get => _isRunning;
        set { if (Set(ref _isRunning, value)) Raise(nameof(RunButtonText)); }
    }
    public string RunButtonText => IsRunning ? "⏸  Szünet" : "▶  Indítás";

    private bool _safetyEnabled = true;
    public bool SafetyEnabled
    {
        get => _safetyEnabled;
        set
        {
            if (Set(ref _safetyEnabled, value))
                Log(value ? "Biztonságos üzem: vágányút-ellenőrzés BE." :
                    "FIGYELEM! A biztonsági vágányút-ellenőrzés KIKAPCSOLVA.", value ? "success" : "danger");
        }
    }

    private double _timeFactor = 1;
    public double TimeFactor
    {
        get => _timeFactor;
        set
        {
            if (Set(ref _timeFactor, value)) Raise(nameof(TimeFactorText));
        }
    }
    public string TimeFactorText => $"{TimeFactor:0}×";

    private double _elapsed;
    public string ClockText => TimeSpan.FromHours(8).Add(TimeSpan.FromSeconds(_elapsed)).ToString(@"hh\:mm\:ss");

    private int _arrivedCount;
    public int ArrivedCount { get => _arrivedCount; private set => Set(ref _arrivedCount, value); }

    private int _collisionCount;
    public int CollisionCount { get => _collisionCount; private set => Set(ref _collisionCount, value); }

    public int ActiveCount => Trains.Count;

    // A négy vágányszakasz foglaltsága élőben megjelenik a biztosítóberendezési térképen.
    private bool IsBusy(string section) => Trains.Any(t =>
        Occupies(t, section) || t.PendingSection == section);
    public string WestSectionLabel => IsBusy("NYUGAT") ? "NYUGATI BLOKK: FOGLALT" : "NYUGATI BLOKK: SZABAD";
    public string EastSectionLabel => IsBusy("KELET") ? "KELETI BLOKK: FOGLALT" : "KELETI BLOKK: SZABAD";
    public string Track1SectionLabel => IsBusy("VÁGÁNY 1") ? "1. VÁGÁNY: FOGLALT" : "1. VÁGÁNY: SZABAD";
    public string Track2SectionLabel => IsBusy("VÁGÁNY 2") ? "2. VÁGÁNY: FOGLALT" : "2. VÁGÁNY: SZABAD";
    public Brush WestSectionBrush => IsBusy("NYUGAT") ? Brushes.Salmon : Brushes.MediumSpringGreen;
    public Brush EastSectionBrush => IsBusy("KELET") ? Brushes.Salmon : Brushes.MediumSpringGreen;
    public Brush Track1SectionBrush => IsBusy("VÁGÁNY 1") ? Brushes.Salmon : Brushes.MediumSpringGreen;
    public Brush Track2SectionBrush => IsBusy("VÁGÁNY 2") ? Brushes.Salmon : Brushes.MediumSpringGreen;

    private void RefreshSectionIndicators()
    {
        Raise(nameof(WestSectionLabel)); Raise(nameof(WestSectionBrush));
        Raise(nameof(EastSectionLabel)); Raise(nameof(EastSectionBrush));
        Raise(nameof(Track1SectionLabel)); Raise(nameof(Track1SectionBrush));
        Raise(nameof(Track2SectionLabel)); Raise(nameof(Track2SectionBrush));
    }

    private string _systemMessage = "A biztosítóberendezés üzemkész. Válassz jelzőt a pályarajzon!";
    public string SystemMessage { get => _systemMessage; private set => Set(ref _systemMessage, value); }

    private int _manualCounter = 9000;
    // A várólistában lévő vonatok még nincsenek a pályarajzon.
    private sealed record RequestedTrain(string Number, int Direction, TrainType Type,
        string Destination, double RequestedAt);
    private readonly List<RequestedTrain> _manualQueue = new();

    public int WaitingCount => Timetable.Count(p => !p.Spawned && p.DueSecond <= _elapsed) + _manualQueue.Count;
    public string WaitingSummary
    {
        get
        {
            int west = Timetable.Count(p => !p.Spawned && p.DueSecond <= _elapsed && p.Direction > 0)
                + _manualQueue.Count(p => p.Direction > 0);
            int east = WaitingCount - west;
            return WaitingCount == 0
                ? "Nincs várakozó érkezés."
                : $"Várakozik: {west} nyugatról, {east} keletről. A vonatok a nyílt vonalon, a rajzon kívül várnak.";
        }
    }
    private void RefreshWaitingIndicators()
    {
        Raise(nameof(WaitingCount));
        Raise(nameof(WaitingSummary));
    }

    public DispatchEngine() => Reset();

    public void Reset()
    {
        Trains.Clear();
        Signals.Clear();
        Turnouts.Clear();
        Drivers.Clear();
        Timetable.Clear();
        Journal.Clear();
        _elapsed = 0;
        _manualCounter = 9000;
        _manualQueue.Clear();
        SelectedTrain = null;
        SelectedSignal = null;
        SelectedTurnout = null;
        ArrivedCount = 0;
        CollisionCount = 0;
        IsRunning = true;
        SafetyEnabled = true;
        SystemMessage = "Állomás üzemkész. Állíts váltót, majd jelzőt, és engedd a vonatokat!";

        Drivers.Add(new Driver("Kovács András", "22 év gyakorlat", 1.15, "MV-101"));
        Drivers.Add(new Driver("Szabó Anna", "13 év gyakorlat", 1.10, "MV-204"));
        Drivers.Add(new Driver("Nagy Péter", "8 év gyakorlat", 0.95, "MV-116"));
        Drivers.Add(new Driver("Tóth Eszter", "18 év gyakorlat", 1.12, "MV-310"));
        Drivers.Add(new Driver("Farkas Gábor", "5 év gyakorlat", 0.90, "MV-228"));
        Drivers.Add(new Driver("Molnár Dóra", "11 év gyakorlat", 1.05, "MV-177"));
        Drivers.Add(new Driver("Varga Balázs", "16 év gyakorlat", 1.08, "MV-502"));
        Drivers.Add(new Driver("Kiss Réka", "7 év gyakorlat", 0.97, "MV-148"));

        // X értékek: nyugati bejárat 260, keleti bejárat 960,
        // 1./2. vágány keleti kijárat 745, nyugati kijárat 430.
        Signals.Add(new Signal("N-BE", "Nyugati bejárati jelző", 260, +1, -1, 248, 137));
        Signals.Add(new Signal("K-BE", "Keleti bejárati jelző", 960, -1, -1, 948, 137));
        Signals.Add(new Signal("V1-K", "1. vágány keleti kijárati jelző", 745, +1, 0, 733, 137));
        Signals.Add(new Signal("V2-K", "2. vágány keleti kijárati jelző", 745, +1, 1, 733, 260));
        Signals.Add(new Signal("V1-N", "1. vágány nyugati kijárati jelző", 430, -1, 0, 418, 137));
        Signals.Add(new Signal("V2-N", "2. vágány nyugati kijárati jelző", 430, -1, 1, 418, 260));

        Turnouts.Add(new Turnout("W1", "Nyugati váltó", 305, 48));
        Turnouts.Add(new Turnout("W2", "Keleti váltó", 800, 48));
        SelectedSignal = Signals[0];
        SelectedTurnout = WestTurnout;

        AddPlan("S 2412", 2, +1, TrainType.Szemely, "Tiszaváros", 0);
        AddPlan("IC 502", 11, -1, TrainType.InterCity, "Hegyeshalom", 1);
        AddPlan("G 921", 27, +1, TrainType.Teher, "Rendezőpályaudvar", 2);
        AddPlan("S 2420", 38, -1, TrainType.Szemely, "Berekfalva", 3);
        AddPlan("IC 506", 52, +1, TrainType.InterCity, "Tiszaváros", 4);
        AddPlan("S 2431", 68, -1, TrainType.Szemely, "Hegyeshalom", 5);
        AddPlan("G 935", 81, -1, TrainType.Teher, "Berekfalva", 6);
        AddPlan("IC 511", 98, +1, TrainType.InterCity, "Tiszaváros", 7);
        AddPlan("S 2440", 116, +1, TrainType.Szemely, "Tiszaváros", 0);
        AddPlan("S 2445", 136, -1, TrainType.Szemely, "Hegyeshalom", 1);
        Raise(nameof(ActiveCount));
        RefreshWaitingIndicators();
        Raise(nameof(ClockText));
        Log("Forgalmi szolgálat átvéve. A jelzők alapállásban vörösek.");
        UpdateTurnoutLocks();
        RefreshSectionIndicators();
    }

    private void AddPlan(string number, int due, int direction, TrainType type, string destination, int driver)
        => Timetable.Add(new ScheduleItem(number, due, direction, type, destination, Drivers[driver]));

    public void Tick(double realSeconds)
    {
        if (!IsRunning) return;
        double dt = Math.Min(realSeconds * TimeFactor, 0.30);
        Advance(dt);
    }

    // A "+1 mp" léptetés a szüneteltetett játékban is működik.
    public void Step()
    {
        for (int i = 0; i < 20; i++) Advance(0.05);
    }

    private void Advance(double dt)
    {
        if (CollisionCount > 0 && !IsRunning) return;
        _elapsed += dt;
        Raise(nameof(ClockText));
        // A már közlekedő szerelvények és távozások feldolgozása megelőzi az új belépéseket.
        foreach (var train in Trains.ToList())
            MoveTrain(train, dt);
        DetectCollisions();
        CompleteDepartures();
        ProcessWaitingTrains();
        UpdateTurnoutLocks();
        RefreshSectionIndicators();
    }

    private void ProcessWaitingTrains()
    {
        if (CollisionCount > 0) return; // Baleset után ne érkezzen új vonat.

        // Menetrendi és rendkívüli vonatok közös, időrend szerinti feldolgozása.
        var due = Timetable.Where(p => !p.Spawned && p.DueSecond <= _elapsed)
            .Select(p => (Time: (double)p.DueSecond, Plan: p, Manual: (RequestedTrain?)null));
        var manual = _manualQueue.Select(p => (Time: p.RequestedAt,
            Plan: (ScheduleItem?)null, Manual: (RequestedTrain?)p));

        foreach (var request in due.Concat(manual).OrderBy(p => p.Time).ToList())
        {
            var plan = request.Plan;
            var custom = request.Manual;
            int direction = plan?.Direction ?? custom!.Direction;
            if (!CanSpawn(direction, out string reason))
            {
                if (plan != null && plan.Status != reason)
                {
                    plan.Status = reason;
                    Log($"{plan.Number}: {reason.ToLowerInvariant()} A nyílt vonalon várakozik.", "warning");
                }
                continue;
            }

            Driver? driver = plan?.Driver ?? Drivers.FirstOrDefault(d => d.AssignedTrain == "Szabad");
            if (driver == null || driver.AssignedTrain != "Szabad")
            {
                if (plan != null) plan.Status = "Mozdonyvezetőre vár";
                continue;
            }

            string number = plan?.Number ?? custom!.Number;
            string destination = plan?.Destination ?? custom!.Destination;
            TrainType type = plan?.Type ?? custom!.Type;
            if (plan != null)
            {
                plan.Spawned = true;
                plan.Status = "Forgalomban";
            }
            else if (custom != null) _manualQueue.Remove(custom);
            CreateTrain(number, destination, type, driver, direction);
        }
        RefreshWaitingIndicators();
    }

    /// <summary>
    /// Érkezés csak szabad bejárati szakaszra. Biztonságos üzemben
    /// a szemből távozó vonat teljes kihaladását is kivárjuk.
    /// Kikapcsolt védelemnél sem engedélyezünk egymásba megjelenést.
    /// </summary>
    private bool CanSpawn(int direction, out string reason)
    {
        string side = direction > 0 ? "nyugati" : "keleti";
        double start = direction > 0 ? 95 : 1090;
        if (Trains.Any(t => !t.Crashed && Math.Abs(t.X - start) < Train.Length + 70))
        {
            reason = $"Vár: {side} bejárat";
            return false;
        }

        if (SafetyEnabled && Trains.Any(t => !t.Crashed && t.Direction != direction))
        {
            reason = "Vár: kihaladó vonat";
            return false;
        }

        // Két azonos irányból érkező vonat között maradjon megfelelő térköz.
        if (Trains.Any(t => !t.Crashed && t.Direction == direction &&
            (direction > 0 ? t.X - Train.Length <= WestPoint + 18
                           : t.X + Train.Length >= EastPoint - 18)))
        {
            reason = "Vár: bejárat foglalt";
            return false;
        }
        reason = "";
        return true;
    }

    public void AddManualTrain(int direction, TrainType type)
    {
        if (_manualQueue.Count >= 16)
        {
            Log("A rendkívüli vonatok várólistája megtelt (16 járat).", "warning");
            SystemMessage = "A rendkívüli várólista megtelt.";
            return;
        }
        string number = $"R {++_manualCounter}";
        _manualQueue.Add(new RequestedTrain(number, direction, type,
            direction > 0 ? "Keleti végállomás" : "Nyugati végállomás", _elapsed));
        Log($"{number}: rendkívüli menet rögzítve, a nyílt vonalon vár a belépésre.", "info");
        SystemMessage = $"{number} felvéve a várakozási sorba. Csak szabad bevezető szakaszra lép be.";
        ProcessWaitingTrains();
    }

    private void CreateTrain(string number, string destination, TrainType type, Driver driver, int direction)
    {
        var train = new Train(number, destination, type, driver, direction, direction > 0 ? 95 : 1090);
        driver.AssignedTrain = number;
        driver.RadioStatus = "Bejelentkezett, közlekedési engedélyre vár";
        Trains.Add(train);
        SelectedTrain ??= train;
        Raise(nameof(ActiveCount));
        RefreshSectionIndicators();
        Log($"{number} ({train.KindText}) belépett {(direction > 0 ? "nyugatról" : "keletről")}. Vezető: {driver.Name}.", "success");
    }

    public void SetSignal(Signal? signal, bool green)
    {
        if (signal == null) return;
        if (signal.IsGreen == green) return;
        if (green && SafetyEnabled && !CanClearSignal(signal, out string reason))
        {
            Log($"{signal.Code}: szabad jelzés elutasítva. {reason}", "warning");
            SystemMessage = $"Vágányút nem állítható: {reason}";
            return;
        }
        signal.IsGreen = green;
        UpdateTurnoutLocks();
        if (green)
        {
            Log($"{signal.Code} szabadra állítva → {DestinationFor(signal)}.", SafetyEnabled ? "success" : "danger");
            SystemMessage = $"{signal.Code}: SZABAD. A vágányút {(SafetyEnabled ? "ellenőrzött" : "NEM ELLENŐRZÖTT")}!";
        }
        else
        {
            Log($"{signal.Code}: MEGÁLLJ jelzés.");
            SystemMessage = $"{signal.Code} vörösre állítva.";
        }
    }

    private bool CanClearSignal(Signal signal, out string reason)
    {
        string destination = DestinationFor(signal);
        if (signal.Track >= 0)
        {
            Turnout point = signal.Direction > 0 ? EastTurnout : WestTurnout;
            if (point.Track != signal.Track)
            {
                reason = $"{point.Code} váltó nem a {signal.Track + 1}. vágányra áll.";
                return false;
            }
        }

        if (Trains.Any(t => Occupies(t, destination) || t.PendingSection == destination))
        {
            reason = $"{destination} szakasz foglalt vagy foglalás alatt áll.";
            return false;
        }

        if (Signals.Any(s => s != signal && s.IsGreen && DestinationFor(s) == destination))
        {
            reason = "Másik szabad jelző ugyanarra a szakaszra vezet.";
            return false;
        }
        reason = "";
        return true;
    }

    private string DestinationFor(Signal s) => s.Code switch
    {
        "N-BE" => WestTurnout.Track == 0 ? "VÁGÁNY 1" : "VÁGÁNY 2",
        "K-BE" => EastTurnout.Track == 0 ? "VÁGÁNY 1" : "VÁGÁNY 2",
        "V1-N" or "V2-N" => "NYUGAT",
        "V1-K" or "V2-K" => "KELET",
        _ => "ISMERETLEN"
    };

    private static bool Occupies(Train t, string section)
    {
        double tail = t.X - t.Direction * Train.Length;
        double min = Math.Min(t.X, tail);
        double max = Math.Max(t.X, tail);
        return section switch
        {
            "NYUGAT" => min < WestPoint && max > 35,
            "KELET" => max > EastPoint && min < 1180,
            "VÁGÁNY 1" => t.Track == 0 && max > WestPoint && min < EastPoint,
            "VÁGÁNY 2" => t.Track == 1 && max > WestPoint && min < EastPoint,
            _ => false
        };
    }

    public void ToggleTurnout(Turnout? point)
    {
        if (point == null) return;
        UpdateTurnoutLocks();
        if (point.IsLocked && SafetyEnabled)
        {
            Log($"{point.Code} váltó állítása tiltva: lezárt vágányút vagy áthaladó vonat!", "warning");
            SystemMessage = $"{point.Code} lezárva, amíg vonat tartózkodik rajta vagy vágányút foglalja.";
            return;
        }
        point.Track = 1 - point.Track;
        Log($"{point.Code} váltó átállítva: {point.RouteText}.", SafetyEnabled ? "success" : "danger");
        SystemMessage = $"{point.Code}: {point.RouteText}.";
        UpdateTurnoutLocks();
    }

    private void UpdateTurnoutLocks()
    {
        // A kijárati jelző előtt álló vonat még nem zárja le a kitérőt:
        // így a forgalmista ekkor is be tudja állítani a megfelelő kijárati vágányutat.
        WestTurnout.IsLocked = Signals.Any(s => s.IsGreen && (s.Code == "N-BE" || s.Code.EndsWith("-N")))
            || Trains.Any(t => !t.Crashed && t.Track >= 0 &&
                (t.Direction > 0 ? t.X > 260 && t.X < 510 : t.X > 245 && t.X < 430));
        EastTurnout.IsLocked = Signals.Any(s => s.IsGreen && (s.Code == "K-BE" || s.Code.EndsWith("-K")))
            || Trains.Any(t => !t.Crashed && t.Track >= 0 &&
                (t.Direction < 0 ? t.X > 665 && t.X < 960 : t.X > 745 && t.X < 910));
    }

    public void StopSelected()
    {
        if (SelectedTrain is not { Crashed: false } t) return;
        t.ManualHold = true;
        t.Driver.RadioStatus = "Forgalmi utasítás: megállás";
        Log($"{t.Number}: mozdonyvezetőnek MEGÁLLÁS utasítás küldve.", "warning");
    }

    public void ResumeSelected()
    {
        if (SelectedTrain is not { Crashed: false } t) return;
        t.ManualHold = false;
        t.Emergency = false;
        t.Driver.RadioStatus = "Indulás engedélyezve, jelzőket figyeli";
        Log($"{t.Number}: mozdonyvezető részére INDULÁS utasítás kiadva.", "success");
    }

    public void EmergencySelected()
    {
        if (SelectedTrain is not { Crashed: false } t) return;
        t.Speed = 0;
        t.ManualHold = true;
        t.Emergency = true;
        t.Status = "VÉSZFÉK";
        t.Driver.RadioStatus = "VÉSZFÉKEZÉS VÉGREHAJTVA";
        Log($"{t.Number}: VÉSZFÉK!", "danger");
    }

    public void PassRedSelected()
    {
        if (SelectedTrain is not { Crashed: false } t) return;
        t.IgnoreNextRed = true;
        t.ManualHold = false;
        t.Emergency = false;
        t.Driver.RadioStatus = "VESZÉLYES PARANCS: következő jelző figyelmen kívül";
        Log($"{t.Number}: VESZÉLYES utasítás! Következő vörös jelző meghaladható.", "danger");
        SystemMessage = "Veszélyes utasítás kiadva. Ütközés következhet be!";
    }

    private Signal? NextSignal(Train t)
    {
        if (t.Direction > 0)
        {
            if (t.Track < 0 && t.X < 260) return Signals[0];
            if (t.Track >= 0 && t.X < 745) return Signals[t.Track == 0 ? 2 : 3];
        }
        else
        {
            if (t.Track < 0 && t.X > 960) return Signals[1];
            if (t.Track >= 0 && t.X > 430) return Signals[t.Track == 0 ? 4 : 5];
        }
        return null;
    }

    private void MoveTrain(Train train, double dt)
    {
        if (train.Crashed) return;
        Signal? next = NextSignal(train);
        double target = train.MaxSpeed;
        bool waitingAtRed = false;
        double braking = 80 * train.Driver.BrakeFactor;
        if (next != null && !next.IsGreen && !train.IgnoreNextRed)
        {
            double remaining = train.Direction * (next.Position - train.X) - 18;
            target = Math.Min(target, Math.Sqrt(2 * braking * Math.Max(0, remaining)));
            waitingAtRed = remaining < 22;
        }
        if (train.ManualHold) target = 0;

        // Hátsó ráfutás elleni követési távolság, csak biztonságos üzemben.
        if (SafetyEnabled)
        {
            foreach (var other in Trains)
            {
                if (other == train || other.Crashed || other.Direction != train.Direction) continue;
                double gap = train.Direction * (other.X - train.X) - Train.Length - 19;
                if (gap < -Train.Length || gap > 230) continue;
                if (Math.Abs(other.CenterY - train.CenterY) > 28 &&
                    train.X > 415 && train.X < 740 && other.X > 415 && other.X < 740) continue;
                target = Math.Min(target, Math.Sqrt(2 * braking * Math.Max(0, gap)));
            }
        }

        double acceleration = train.Type == TrainType.Teher ? 24 : 36;
        double delta = target > train.Speed ? acceleration * dt : braking * dt;
        train.Speed = MoveTowards(train.Speed, target, delta);
        double oldX = train.X;
        double newX = oldX + train.Direction * train.Speed * dt;

        // Matematikai védőkorlát: vörös jelző előtt ne csússzon át a vonat.
        if (next != null && !next.IsGreen && !train.IgnoreNextRed)
        {
            double stop = next.Position - train.Direction * 18;
            if ((train.Direction > 0 && newX > stop) || (train.Direction < 0 && newX < stop))
            {
                newX = stop;
                train.Speed = 0;
            }
        }

        train.X = newX;
        if (next != null && train.Direction * (oldX - next.Position) < 0 &&
            train.Direction * (newX - next.Position) >= 0)
            PassSignal(train, next);

        if (train.PendingSection != null && Occupies(train, train.PendingSection))
            train.PendingSection = null;

        train.UpdateLayout();
        string state = train.ManualHold ? (train.Emergency ? "Vészfékezve" : "Forgalmi utasításra áll")
            : waitingAtRed && train.Speed < 5 ? "Vörös jelzőnél vár" : "Menetben";
        train.Status = state;
        train.Driver.RadioStatus = state;
    }

    private static double MoveTowards(double current, double target, double maxDelta)
    {
        if (current < target) return Math.Min(current + maxDelta, target);
        return Math.Max(current - maxDelta, target);
    }

    private void PassSignal(Train train, Signal signal)
    {
        bool violated = !signal.IsGreen;
        if (violated)
        {
            Log($"JELZŐMEGHALADÁS: {train.Number} átment a vörös {signal.Code} jelzőn!", "danger");
            train.IgnoreNextRed = false;
        }
        else
        {
            Log($"{train.Number} elhaladt a {signal.Code} jelző mellett.", "success");
            signal.IsGreen = false; // automatikus visszaállás a vonat elhaladása után
        }
        train.PendingSection = DestinationFor(signal);
        if (signal.Code == "N-BE") train.Track = WestTurnout.Track;
        if (signal.Code == "K-BE") train.Track = EastTurnout.Track;
        UpdateTurnoutLocks();
    }

    private void DetectCollisions()
    {
        for (int i = 0; i < Trains.Count; i++)
        {
            var first = Trains[i];
            if (first.Crashed) continue;
            for (int j = i + 1; j < Trains.Count; j++)
            {
                var second = Trains[j];
                if (second.Crashed) continue;
                if (Math.Abs(first.CenterY - second.CenterY) > 29) continue;
                double a1 = Math.Min(first.X, first.X - first.Direction * Train.Length);
                double a2 = Math.Max(first.X, first.X - first.Direction * Train.Length);
                double b1 = Math.Min(second.X, second.X - second.Direction * Train.Length);
                double b2 = Math.Max(second.X, second.X - second.Direction * Train.Length);
                if (Math.Max(a1, b1) < Math.Min(a2, b2) - 6)
                {
                    first.Crashed = second.Crashed = true;
                    first.Speed = second.Speed = 0;
                    first.Status = second.Status = "ÜTKÖZÖTT";
                    first.Driver.RadioStatus = second.Driver.RadioStatus = "BALESET – segítség szükséges";
                    CollisionCount++;
                    foreach (var signal in Signals) signal.IsGreen = false;
                    foreach (var train in Trains.Where(t => !t.Crashed))
                    {
                        train.ManualHold = true;
                        train.Speed = 0;
                    }
                    var p1 = Timetable.FirstOrDefault(p => p.Number == first.Number);
                    var p2 = Timetable.FirstOrDefault(p => p.Number == second.Number);
                    if (p1 != null) p1.Status = "BALESET";
                    if (p2 != null) p2.Status = "BALESET";
                    Log($"ÜTKÖZÉS! {first.Number} és {second.Number} ütközött. A forgalom leállt!", "danger");
                    SystemMessage = $"BALESET: {first.Number} + {second.Number}. Indíts új szolgálatot az ÚJRAINDÍTÁS gombbal.";
                    IsRunning = false;
                    return;
                }
            }
        }
    }

    private void CompleteDepartures()
    {
        foreach (var train in Trains.Where(t => !t.Crashed &&
                     (t.Direction > 0 ? t.X > 1270 : t.X < -130)).ToList())
        {
            train.Driver.AssignedTrain = "Szabad";
            train.Driver.RadioStatus = "Szolgálatra kész";
            Trains.Remove(train);
            ArrivedCount++;
            if (SelectedTrain == train) SelectedTrain = Trains.FirstOrDefault();
            var plan = Timetable.FirstOrDefault(p => p.Number == train.Number);
            if (plan != null) plan.Status = "Teljesítve";
            Log($"{train.Number} elhagyta az állomás térségét, menet rendben.", "success");
            Raise(nameof(ActiveCount));
        }
    }

    private void Log(string message, string level = "info")
    {
        Journal.Insert(0, new JournalEntry(ClockText, message, level));
        while (Journal.Count > 110) Journal.RemoveAt(Journal.Count - 1);
    }
}
