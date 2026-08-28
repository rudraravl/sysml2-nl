package BaglessSuctionSystem {

    import ScalarValues::*;

    // ===== Value Types with Units =====

    scalar value type Pressure > Real { unit 'Pa'; }
    scalar value type VacuumPressure > Real { unit 'Pa'; }
    scalar value type VolumetricFlowRate > Real { unit 'm^3/s'; }
    scalar value type ElectricalPower > Real { unit 'W'; }
    scalar value type Mass > Real { unit 'kg'; }
    scalar value type Volume > Real { unit 'm^3'; }
    scalar value type AngularSpeed > Real { unit 'rpm'; }
    scalar value type Percentage > Real { unit '%'; }
    scalar value type Temperature > Real { unit 'degC'; }
    scalar value type ElectricalCurrent > Real { unit 'A'; }
    scalar value type Voltage > Real { unit 'V'; }
    scalar value type ParticleDiameter > Real { unit 'um'; }
    scalar value type TimeDuration > Real { unit 's'; }
    scalar value type Length > Real { unit 'm'; }

    // ===== Enumerations =====

    enum def FilterCondition {
        clean;
        partiallyLoaded;
        fullyClogged;
    }

    enum def OperationalState {
        idle;
        starting;
        running;
        alerting;
        halted;
    }

    enum def AlertLevel {
        none;
        warning;
        critical;
    }

    enum def MotorState {
        off;
        ramping;
        running;
        overloaded;
        faulted;
    }

    // ===== Item Definitions =====

    item def AirFlow {
        attribute pressure : Pressure;
        attribute flowRate : VolumetricFlowRate;
        attribute temperature : Temperature;
    }

    item def ContaminatedAirFlow :> AirFlow {
        attribute debrisLoad : Mass;
        attribute maxParticleSize : ParticleDiameter;
    }

    item def PartiallyCleanedAirFlow :> AirFlow {
        attribute residualDustLoad : Mass;
        attribute maxParticleSize : ParticleDiameter;
    }

    item def CleanAirFlow :> AirFlow {
        attribute residualEfficiency : Percentage;
    }

    item def SolidDebris {
        attribute mass : Mass;
        attribute averageParticleSize : ParticleDiameter;
    }

    item def FineDust :> SolidDebris {}

    item def PowerCommand {
        attribute targetPower : ElectricalPower;
    }

    item def DriveSignal {
        attribute speed : AngularSpeed;
    }

    item def VacuumReading {
        attribute measuredVacuum : VacuumPressure;
        attribute timestamp : TimeDuration;
    }

    item def BinFillReading {
        attribute fillPercentage : Percentage;
        attribute timestamp : TimeDuration;
    }

    item def FilterStatusReading {
        attribute condition : FilterCondition;
        attribute loadPercentage : Percentage;
        attribute timestamp : TimeDuration;
    }

    // ===== Port Definitions =====

    port def AirFlowPort {
        in item air : AirFlow;
    }

    port def DebrisPort {
        in item debris : SolidDebris;
    }

    port def DrivePort {
        in item drive : DriveSignal;
    }

    port def PowerPort {
        in item command : PowerCommand;
    }

    port def VacuumReadingPort {
        in item reading : VacuumReading;
    }

    port def BinFillReadingPort {
        in item reading : BinFillReading;
    }

    port def FilterStatusPort {
        in item reading : FilterStatusReading;
    }

    // ===== Action Definitions =====

    action def GenerateSuction {
        in driveSpeed : AngularSpeed;
        out vacuum : VacuumPressure;
        out flowRate : VolumetricFlowRate;
    }

    action def SeparateDebris {
        in contaminatedAir : ContaminatedAirFlow;
        out partiallyCleanedAir : PartiallyCleanedAirFlow;
        out separatedDebris : SolidDebris;
    }

    action def FilterAir {
        in incomingAir : PartiallyCleanedAirFlow;
        out cleanAir : CleanAirFlow;
        out trappedDust : FineDust;
    }

    action def MeasureVacuum {
        in airFlow : AirFlow;
        out reading : VacuumReading;
    }

    action def MeasureBinFill {
        out reading : BinFillReading;
    }

    action def ComputeMotorPower {
        in measuredVacuum : VacuumPressure;
        in targetVacuum : VacuumPressure;
        in binFill : Percentage;
        in filterCondition : FilterCondition;
        out motorPower : ElectricalPower;
        out alert : AlertLevel;
        out state : OperationalState;
    }

    // ===== Part Definitions =====

    part def ElectricMotor {
        attribute ratedPower : ElectricalPower = 2000 [W];
        attribute maxSpeed : AngularSpeed = 30000 [rpm];
        attribute operatingVoltage : Voltage = 230 [V];
        attribute maxCurrent : ElectricalCurrent = 15 [A];
        attribute efficiency : Percentage = 85 [%];
        attribute resetCommandReceived : Boolean = false;

        port powerInput : PowerPort;
        port driveOutput : ~DrivePort;

        attribute currentSpeed : AngularSpeed = 0 [rpm];
        attribute currentPower : ElectricalPower = 0 [W];
        attribute currentState : MotorState = MotorState::off;

        state motorBehavior {
            entry; then off;

            state off {
                entry {
                    assign currentSpeed = 0 [rpm];
                    assign currentPower = 0 [W];
                    assign currentState = MotorState::off;
                }
            }

            state ramping {
                entry { assign currentState = MotorState::ramping; }
                do { increase speed gradually toward target based on commanded power; }
            }

            state running {
                entry { assign currentState = MotorState::running; }
                do { maintain speed proportional to commanded power; }
            }

            state overloaded {
                entry { assign currentState = MotorState::overloaded; }
                do { reduce output; monitor current draw; }
            }

            state faulted {
                entry {
                    assign currentState = MotorState::faulted;
                    assign currentSpeed = 0 [rpm];
                    assign currentPower = 0 [W];
                }
            }

            transition off -> ramping
                when powerInput.command.targetPower > 0 [W];

            transition ramping -> running
                when currentSpeed >= maxSpeed * 0.9;

            transition running -> off
                when powerInput.command.targetPower == 0 [W];

            transition running -> overloaded
                when currentPower > ratedPower * 1.15;

            transition overloaded -> faulted
                when currentPower > ratedPower * 1.5;

            transition overloaded -> running
                when currentPower <= ratedPower;

            transition faulted -> off
                when resetCommandReceived == true;
        }
    }

    part def CentrifugalImpeller {
        attribute bladeDiameter : Length = 0.15 [m];
        attribute numberOfBlades : Integer = 9;
        attribute maxRPM : AngularSpeed = 30000 [rpm];
        attribute efficiency : Percentage = 78 [%];

        port driveInput : DrivePort;
        port suctionPort : AirFlowPort;
        port dischargePort : ~AirFlowPort;

        attribute generatedVacuum : VacuumPressure = 0 [Pa];
        attribute generatedFlowRate : VolumetricFlowRate = 0 ['m^3/s'];
        attribute currentSpeed : AngularSpeed = 0 [rpm];

        action generateSuction : GenerateSuction {
            in driveSpeed = driveInput.drive.speed;
            out vacuum = generatedVacuum;
            out flowRate = generatedFlowRate;
        }
    }

    part def CycloneSeparator {
        attribute bodyDiameter : Length = 0.12 [m];
        attribute bodyHeight : Length = 0.35 [m];
        attribute separationEfficiency : Percentage = 95 [%];
        attribute cutoffParticleSize : ParticleDiameter = 10 [um];
        attribute pressureDrop : Pressure = 500 [Pa];

        port airInlet : AirFlowPort;
        port airOutlet : ~AirFlowPort;
        port debrisOutlet : ~DebrisPort;

        action separateDebris : SeparateDebris {
            in contaminatedAir = airInlet.air;
            out partiallyCleanedAir = airOutlet.air;
            out separatedDebris = debrisOutlet.debris;
        }
    }

    part def DebrisCollectionBin {
        attribute capacity : Volume = 0.05 ['m^3'];
        attribute currentFillLevel : Percentage = 0 [%];
        attribute isRemovable : Boolean = true;
        attribute collectedMass : Mass = 0 [kg];
        attribute isFull : Boolean = false;

        port debrisInlet : DebrisPort;

        state binFillBehavior {
            entry; then notFull;

            state notFull {
                entry { assign isFull = false; }
                do { accumulate incoming debris; update fill level; }
            }

            state nearlyFull {
                entry { assign isFull = false; }
                do { continue accumulating; signal approaching capacity; }
            }

            state full {
                entry { assign isFull = true; }
                do { signal bin full alert; }
            }

            transition notFull -> nearlyFull
                when currentFillLevel >= 80 [%];

            transition nearlyFull -> full
                when currentFillLevel >= 100 [%];

            transition nearlyFull -> notFull
                when currentFillLevel < 70 [%];

            transition full -> notFull
                when currentFillLevel < 10 [%];
        }
    }

    part def HepaFilter {
        attribute filterGrade : String = "H13";
        attribute filtrationEfficiency : Percentage = 99.95 [%];
        attribute minParticleSize : ParticleDiameter = 0.3 [um];
        attribute surfaceArea : Real = 1.5;
        attribute maxLoadCapacity : Mass = 0.5 [kg];
        attribute currentLoad : Mass = 0 [kg];
        attribute loadPercentage : Percentage = 0 [%];
        attribute condition : FilterCondition = FilterCondition::clean;
        attribute filterReplaced : Boolean = false;

        port airInlet : AirFlowPort;
        port airOutlet : ~AirFlowPort;
        port statusOutput : ~FilterStatusPort;

        action filterAir : FilterAir {
            in incomingAir = airInlet.air;
            out cleanAir = airOutlet.air;
        }

        state filterConditionBehavior {
            entry; then clean;

            state clean {
                entry { assign condition = FilterCondition::clean; }
                do { filter air at full efficiency; update load; }
            }

            state partiallyLoaded {
                entry { assign condition = FilterCondition::partiallyLoaded; }
                do { filter air with slightly reduced efficiency; update load; }
            }

            state fullyClogged {
                entry { assign condition = FilterCondition::fullyClogged; }
                do { severely restrict airflow; signal critical alert; }
            }

            transition clean -> partiallyLoaded
                when loadPercentage >= 30 [%];

            transition partiallyLoaded -> fullyClogged
                when loadPercentage >= 90 [%];

            transition fullyClogged -> clean
                when filterReplaced == true;

            transition partiallyLoaded -> clean
                when filterReplaced == true;
        }
    }

    part def PressureSensor {
        attribute measurementRange : Pressure = 50000 [Pa];
        attribute accuracy : Percentage = 98 [%];
        attribute responseTime : TimeDuration = 0.05 [s];
        attribute samplingRate : Real = 100;

        port readingOutput : ~VacuumReadingPort;

        action measureVacuum : MeasureVacuum {
            out reading = readingOutput.reading;
        }
    }

    part def BinFillSensor {
        attribute detectionMethod : String = "capacitive";
        attribute warningThreshold : Percentage = 80 [%];
        attribute fullThreshold : Percentage = 100 [%];
        attribute accuracy : Percentage = 95 [%];

        port readingOutput : ~BinFillReadingPort;

        action measureFillLevel : MeasureBinFill {
            out reading = readingOutput.reading;
        }
    }

    part def ControlUnit {
        attribute targetVacuum : VacuumPressure = 20000 [Pa];
        attribute targetFlowRate : VolumetricFlowRate = 0.05 ['m^3/s'];
        attribute minMotorPower : ElectricalPower = 500 [W];
        attribute maxMotorPower : ElectricalPower = 2000 [W];
        attribute proportionalGain : Real = 0.8;
        attribute integralGain : Real = 0.2;
        attribute derivativeGain : Real = 0.1;
        attribute startCommandReceived : Boolean = false;
        attribute maintenanceComplete : Boolean = false;

        port vacuumInput : VacuumReadingPort;
        port binFillInput : BinFillReadingPort;
        port filterStatusInput : FilterStatusPort;
        port motorCommandOutput : ~PowerPort;

        attribute currentState : OperationalState = OperationalState::idle;
        attribute currentAlert : AlertLevel = AlertLevel::none;
        attribute computedMotorPower : ElectricalPower = 0 [W];
        attribute integralError : Real = 0;
        attribute previousError : Real = 0;

        action computeMotorPower : ComputeMotorPower {
            in measuredVacuum = vacuumInput.reading.measuredVacuum;
            in targetVacuum = targetVacuum;
            in binFill = binFillInput.reading.fillPercentage;
            in filterCondition = filterStatusInput.reading.condition;
            out motorPower = computedMotorPower;
            out alert = currentAlert;
            out state = currentState;
        }

        state controlBehavior {
            entry; then idle;

            state idle {
                entry {
                    assign computedMotorPower = 0 [W];
                    assign currentAlert = AlertLevel::none;
                    assign currentState = OperationalState::idle;
                }
                do { wait for start command; }
            }

            state starting {
                entry { assign currentState = OperationalState::starting; }
                do { ramp motor power from minimum toward target; }
            }

            state running {
                entry { assign currentState = OperationalState::running; }
                do {
                    monitor vacuum sensor reading;
                    execute PID power adjustment based on vacuum error;
                    monitor bin fill level;
                    monitor filter condition;
                }
            }

            state alerting {
                entry {
                    assign currentState = OperationalState::alerting;
                    assign currentAlert = AlertLevel::warning;
                }
                do {
                    reduce motor power to safe level;
                    signal bin full warning;
                    continue limited operation;
                }
            }

            state halted {
                entry {
                    assign currentState = OperationalState::halted;
                    assign computedMotorPower = 0 [W];
                    assign currentAlert = AlertLevel::critical;
                }
                do {
                    signal critical alert;
                    wait for maintenance;
                }
            }

            transition idle -> starting
                when startCommandReceived == true;

            transition starting -> running
                when computedMotorPower >= minMotorPower * 1.5;

            transition running -> alerting
                when binFillInput.reading.fillPercentage >= 80 [%];

            transition running -> halted
                when filterStatusInput.reading.condition == FilterCondition::fullyClogged;

            transition alerting -> halted
                when binFillInput.reading.fillPercentage >= 100 [%];

            transition alerting -> running
                when binFillInput.reading.fillPercentage < 70 [%];

            transition halted -> idle
                when maintenanceComplete == true;
        }
    }

    // ===== Top-level System Assembly =====

    part def BaglessSuctionSystem {
        attribute systemDesignation : String = "Standard";
        attribute isIndustrialGrade : Boolean = false;
        attribute totalWeight : Mass = 12 [kg];
        attribute operatingTemperature : Temperature = 25 [degC];
        attribute nominalVoltage : Voltage = 230 [V];

        port intake : AirFlowPort;
        port exhaust : ~AirFlowPort;

        part motor : ElectricMotor;
        part impeller : CentrifugalImpeller;
        part cyclone : CycloneSeparator;
        part debrisBin : DebrisCollectionBin;
        part hepaFilter : HepaFilter;
        part pressureSensor : PressureSensor;
        part binFillSensor : BinFillSensor;
        part controller : ControlUnit;

        // Control signal connections
        connect controller.motorCommandOutput to motor.powerInput;

        // Mechanical drive connection
        connect motor.driveOutput to impeller.driveInput;

        // Airflow path: intake -> cyclone -> HEPA -> impeller -> exhaust
        connect intake to cyclone.airInlet;
        connect cyclone.airOutlet to hepaFilter.airInlet;
        connect hepaFilter.airOutlet to impeller.suctionPort;
        connect impeller.dischargePort to exhaust;

        // Debris path: cyclone -> bin
        connect cyclone.debrisOutlet to debrisBin.debrisInlet;

        // Sensor signal connections
        connect pressureSensor.readingOutput to controller.vacuumInput;
        connect binFillSensor.readingOutput to controller.binFillInput;
        connect hepaFilter.statusOutput to controller.filterStatusInput;
    }

    // ===== Industrial Configuration =====

    part def IndustrialSuctionSystem :> BaglessSuctionSystem {
        attribute systemDesignation = "Industrial";
        attribute isIndustrialGrade = true;
        attribute totalWeight = 35 [kg];
        attribute nominalVoltage = 400 [V];

        :>> motor {
            redef ratedPower = 5000 [W];
            redef maxSpeed = 40000 [rpm];
            redef operatingVoltage = 400 [V];
            redef maxCurrent = 20 [A];
        }

        :>> impeller {
            redef bladeDiameter = 0.25 [m];
            redef numberOfBlades = 12;
            redef maxRPM = 40000 [rpm];
        }

        :>> cyclone {
            redef bodyDiameter = 0.25 [m];
            redef bodyHeight = 0.6 [m];
            redef separationEfficiency = 97 [%];
        }

        :>> debrisBin {
            redef capacity = 0.2 ['m^3'];
        }

        :>> hepaFilter {
            redef filterGrade = "H14";
            redef filtrationEfficiency = 99.995 [%];
            redef maxLoadCapacity = 2.0 [kg];
            redef surfaceArea = 4.0;
        }

        :>> controller {
            redef targetVacuum = 30000 [Pa];
            redef targetFlowRate = 0.1 ['m^3/s'];
            redef maxMotorPower = 5000 [W];
        }
    }

    // ===== Requirements =====

    requirement def VacuumStrengthRequirement {
        doc "The system shall generate sufficient vacuum pressure for effective debris collection and material transport.";
        attribute minimumVacuum : VacuumPressure = 15000 [Pa];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.impeller.generatedVacuum >= minimumVacuum }
    }

    requirement def AirflowRateRequirement {
        doc "The system shall maintain a minimum volumetric airflow rate to ensure effective transport of debris through the separation stages.";
        attribute minimumFlowRate : VolumetricFlowRate = 0.03 ['m^3/s'];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.impeller.generatedFlowRate >= minimumFlowRate }
    }

    requirement def FiltrationEfficiencyRequirement {
        doc "The HEPA filter shall achieve high filtration efficiency to ensure expelled air is clean and free of harmful particulates.";
        attribute minimumEfficiency : Percentage = 99.95 [%];
        attribute maximumPassingParticleSize : ParticleDiameter = 0.3 [um];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.hepaFilter.filtrationEfficiency >= minimumEfficiency }
    }

    requirement def CycloneSeparationRequirement {
        doc "The cyclone separator shall remove the majority of solid debris before the air reaches the HEPA filter, extending filter life.";
        attribute minimumSeparationEfficiency : Percentage = 90 [%];
        attribute maximumCutoffSize : ParticleDiameter = 15 [um];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.cyclone.separationEfficiency >= minimumSeparationEfficiency }
    }

    requirement def DebrisBinCapacityRequirement {
        doc "The debris collection bin shall have adequate capacity for the intended operational duration between emptying cycles.";
        attribute minimumCapacity : Volume = 0.02 ['m^3'];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.debrisBin.capacity >= minimumCapacity }
    }

    requirement def SafetyHaltRequirement {
        doc "The system shall halt motor operation when the HEPA filter is fully clogged to prevent damage and maintain safety.";
        subject suctionSystem : BaglessSuctionSystem;
        constraint {
            suctionSystem.controller.currentState == OperationalState::halted
            when suctionSystem.hepaFilter.condition == FilterCondition::fullyClogged
        }
    }

    requirement def BinFullAlertRequirement {
        doc "The system shall signal an alert when the debris bin fill level reaches the warning threshold and halt when full.";
        attribute warningThreshold : Percentage = 80 [%];
        attribute haltThreshold : Percentage = 100 [%];
        subject suctionSystem : BaglessSuctionSystem;
        constraint {
            suctionSystem.controller.currentState == OperationalState::alerting
            when suctionSystem.debrisBin.currentFillLevel >= warningThreshold
        }
    }

    requirement def MotorPowerControlRequirement {
        doc "The control unit shall adjust motor power using closed-loop control to maintain target vacuum under varying load conditions.";
        attribute minimumControllablePower : ElectricalPower = 500 [W];
        attribute maximumControllablePower : ElectricalPower = 2000 [W];
        subject suctionSystem : BaglessSuctionSystem;
        constraint {
            suctionSystem.controller.computedMotorPower >= minimumControllablePower
            and suctionSystem.controller.computedMotorPower <= maximumControllablePower
        }
    }

    requirement def FilterMonitoringRequirement {
        doc "The system shall continuously monitor HEPA filter condition and report status as clean, partially loaded, or fully clogged.";
        subject suctionSystem : BaglessSuctionSystem;
        constraint {
            suctionSystem.hepaFilter.condition == FilterCondition::clean
            or suctionSystem.hepaFilter.condition == FilterCondition::partiallyLoaded
            or suctionSystem.hepaFilter.condition == FilterCondition::fullyClogged
        }
    }

    requirement def PressureSensorResponseRequirement {
        doc "The pressure sensor shall respond to vacuum level changes within a specified time to enable effective closed-loop control.";
        attribute maximumResponseTime : TimeDuration = 0.1 [s];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.pressureSensor.responseTime <= maximumResponseTime }
    }

    requirement def ConfigurabilityRequirement {
        doc "The system design shall support an industrial configuration with higher motor power and larger debris collection capacity.";
        subject standardSystem : BaglessSuctionSystem;
        subject industrialSystem : IndustrialSuctionSystem;
        constraint { industrialSystem.motor.ratedPower > standardSystem.motor.ratedPower }
        constraint { industrialSystem.debrisBin.capacity > standardSystem.debrisBin.capacity }
        constraint { industrialSystem.controller.targetVacuum > standardSystem.controller.targetVacuum }
    }

    requirement def TwoStageSeparationRequirement {
        doc "The system shall employ a two-stage separation process: cyclonic separation followed by HEPA filtration.";
        subject suctionSystem : BaglessSuctionSystem;
        constraint {
            suctionSystem.cyclone.separationEfficiency >= 90 [%]
            and suctionSystem.hepaFilter.filtrationEfficiency >= 99.95 [%]
        }
    }

    requirement def ContinuousOperationRequirement {
        doc "The system shall support continuous operation under normal conditions with automatic performance adjustment.";
        subject suctionSystem : BaglessSuctionSystem;
        constraint {
            suctionSystem.controller.currentState == OperationalState::running
            when suctionSystem.debrisBin.currentFillLevel < 80 [%]
            and suctionSystem.hepaFilter.condition != FilterCondition::fullyClogged
        }
    }

    requirement def MotorDriveRequirement {
        doc "The electric motor shall drive the centrifugal impeller at sufficient speed to generate the required vacuum and airflow.";
        attribute minimumDriveSpeed : AngularSpeed = 15000 [rpm];
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.motor.maxSpeed >= minimumDriveSpeed }
    }

    requirement def RemovableBinRequirement {
        doc "The debris collection bin shall be removable for emptying and maintenance.";
        subject suctionSystem : BaglessSuctionSystem;
        constraint { suctionSystem.debrisBin.isRemovable == true }
    }

}
