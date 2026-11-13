namespace Vaganymester.Models;

public sealed class Driver : BindableBase
{
    public string Name { get; }
    public string Experience { get; }
    public double BrakeFactor { get; }
    public string RadioCode { get; }

    private string _assignedTrain = "Szabad";
    public string AssignedTrain { get => _assignedTrain; set => Set(ref _assignedTrain, value); }

    private string _radioStatus = "Szolgálatra kész";
    public string RadioStatus { get => _radioStatus; set => Set(ref _radioStatus, value); }

    public Driver(string name, string experience, double brakeFactor, string radioCode)
    {
        Name = name;
        Experience = experience;
        BrakeFactor = brakeFactor;
        RadioCode = radioCode;
    }
}
