package AthleteSystemModel {

    attribute def Mass {
        :> scalarValues::Real;
        unit = "kg";
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = "m";
    }

    attribute def Time {
        :> scalarValues::Real;
        unit = "s";
    }

    attribute def Speed {
        :> scalarValues::Real;
        unit = "m/s";
    }

    attribute def Power {
        :> scalarValues::Real;
        unit = "W";
    }

    attribute def HeartRate {
        :> scalarValues::Real;
        unit = "beat/min";
    }

    attribute def Energy {
        :> scalarValues::Real;
        unit = "kcal";
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def Force {
        :> scalarValues::Real;
        unit = "N";
    }

    item def Oxygen;
    item def CarbonDioxide;
    item def Nutrients;
    item def Hydration;
    item def MetabolicEnergy;
    item def MotionCommand;
    item def SensorySignal;
    item def MechanicalWork;
    item def WasteHeat;
    item def PerformanceResult;

    port def IntakePort {
        in item oxygen : Oxygen;
        in item nutrients : Nutrients;
        in item hydration : Hydration;
    }

    port def ExhaustPort {
        out item carbonDioxide : CarbonDioxide;
        out item wasteHeat : WasteHeat;
    }

    port def NeuralPort {
        out item command : MotionCommand;
        in item feedback : SensorySignal;
    }

    port def MechanicalOutputPort {
        out item work : MechanicalWork;
        out item result : PerformanceResult;
    }

    part def CardiovascularSystem {
        attribute restingHeartRate : HeartRate = 55;
        attribute activeHeartRate : HeartRate;
        attribute oxygenDeliveryRate : scalarValues::Real;
        port intake : IntakePort;
        port exhaust : ExhaustPort;
        port neural : NeuralPort;
    }

    part def RespiratorySystem {
        attribute ventilationRate : scalarValues::Real;
        attribute oxygenUptake : scalarValues::Real;
        port intake : IntakePort;
        port exhaust : ExhaustPort;
    }

    part def MusculoskeletalSystem {
        attribute peakForce : Force = 2200;
        attribute mechanicalPower : Power;
        attribute strideLength : Length = 1.35;
        port neural : NeuralPort;
        port output : MechanicalOutputPort;
    }

    part def NervousSystem {
        attribute reactionTime : Time = 0.18;
        port control : NeuralPort;
    }

    part def MetabolicSystem {
        attribute storedEnergy : Energy = 2400;
        attribute energyUseRate : Power;
        port intake : IntakePort;
        port exhaust : ExhaustPort;
    }

    part def ThermoregulationSystem {
        attribute coreTemperature : Temperature = 37.0;
        port exhaust : ExhaustPort;
    }

    part def Athlete {
        attribute bodyMass : Mass = 72;
        attribute height : Length = 1.82;
        attribute currentSpeed : Speed;
        attribute availableEnergy : Energy;
        attribute primaryFunction : scalarValues::String =
            "Convert physiological energy, sensory input, and trained motor control into coordinated athletic movement that produces measurable performance.";

        port intake : IntakePort;
        port exhaust : ExhaustPort;
        port output : MechanicalOutputPort;

        part respiratory : RespiratorySystem;
        part cardiovascular : CardiovascularSystem;
        part metabolic : MetabolicSystem;
        part nervous : NervousSystem;
        part musculoskeletal : MusculoskeletalSystem;
        part thermal : ThermoregulationSystem;

        connect intake to respiratory.intake;
        connect intake to metabolic.intake;
        connect respiratory.exhaust to exhaust;
        connect metabolic.exhaust to exhaust;
        connect thermal.exhaust to exhaust;
        connect nervous.control to cardiovascular.neural;
        connect nervous.control to musculoskeletal.neural;
        connect musculoskeletal.output to output;
    }

    action def PrepareForPerformance {
        in item fuel : Nutrients;
        in item water : Hydration;
        out item storedEnergy : MetabolicEnergy;
    }

    action def SenseEnvironment {
        out item perception : SensorySignal;
    }

    action def GenerateMovementPlan {
        in item perception : SensorySignal;
        out item command : MotionCommand;
    }

    action def ExecuteMovement {
        in item command : MotionCommand;
        in item energy : MetabolicEnergy;
        out item work : MechanicalWork;
        out item result : PerformanceResult;
    }

    action def Recover {
        in item carbonDioxide : CarbonDioxide;
        out item restoredCapacity : MetabolicEnergy;
    }

    state def AthleteOperationalState {
        entry action SenseEnvironment;

        state Resting;
        state WarmingUp;
        state Performing;
        state Fatigued;
        state Recovering;

        transition first Resting;

        transition Resting_to_WarmingUp
            first Resting
            then WarmingUp;

        transition WarmingUp_to_Performing
            first WarmingUp
            then Performing;

        transition Performing_to_Fatigued
            first Performing
            then Fatigued;

        transition Fatigued_to_Recovering
            first Fatigued
            then Recovering;

        transition Recovering_to_Resting
            first Recovering
            then Resting;
    }

    requirement def PrimaryFunctionRequirement {
        subject athlete : Athlete;
        require constraint {
            athlete.primaryFunction ==
            "Convert physiological energy, sensory input, and trained motor control into coordinated athletic movement that produces measurable performance."
        }
    }

    requirement def EnergyRequirement {
        subject athlete : Athlete;
        require constraint {
            athlete.availableEnergy >= 300 [Energy]
        }
    }

    requirement def ThermalSafetyRequirement {
        subject athlete : Athlete;
        require constraint {
            athlete.thermal.coreTemperature <= 39.5 [Temperature]
        }
    }

    requirement def PerformanceOutputRequirement {
        subject athlete : Athlete;
        require constraint {
            athlete.currentSpeed >= 0 [Speed]
        }
    }

    part athleteSystem : Athlete {
        attribute bodyMass = 72;
        attribute height = 1.82;
        attribute availableEnergy = 1800;
        attribute currentSpeed = 7.5;
    }

    satisfy PrimaryFunctionRequirement by athleteSystem;
    satisfy EnergyRequirement by athleteSystem;
    satisfy ThermalSafetyRequirement by athleteSystem;
    satisfy PerformanceOutputRequirement by athleteSystem;
}