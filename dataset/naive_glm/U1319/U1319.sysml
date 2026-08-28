package VacuumCleanerModel {

    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Mass;
    import ISQ::Volume;
    import ISQ::Time;
    import ISQ::Energy;
    import ISQ::Power;
    import ISQ::ElectricPotential;
    import ISQ::ElectricCurrent;
    import ISQ::Frequency;
    import ISQ::Speed;
    import ISQ::Pressure;

    // ---------- Value Types ----------

    value def PowerLevel :> Real;
    value def SuctionPressure :> Pressure;
    value def AirflowRate :> Real;
    value def BatteryCharge :> Real;
    value def DustLoad :> Mass;
    value def FilterClogLevel :> Real;
    value def BrushSpeed :> Frequency;
    value def MotorRPM :> Frequency;
    value def Voltage :> ElectricPotential;
    value def Current :> ElectricCurrent;
    value def RuntimeEstimate :> Time;
    value def Temperature :> Real;

    enum OperatingMode { eco, normal, turbo }
    enum SurfaceType { hardFloor, carpet, upholstery }
    enum AlertLevel { info, warning, critical }

    // ---------- Item Types ----------

    item def AirFlow {
        attribute pressure : SuctionPressure;
        attribute flowRate : AirflowRate;
        attribute isDirty : Boolean;
    }

    item def Debris {
        attribute particleSize : Real;
        attribute mass : Mass;
        attribute isFine : Boolean;
    }

    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute mode : OperatingMode;
    }

    item def ControlCommand {
        attribute targetMode : OperatingMode;
        attribute targetSurface : SurfaceType;
        attribute powerLevel : Real;
        attribute brushEnabled : Boolean;
    }

    item def StatusReport {
        attribute batteryLevel : BatteryCharge;
        attribute dustLevel : DustLoad;
        attribute filterClog : FilterClogLevel;
        attribute currentMode : OperatingMode;
        attribute detectedSurface : SurfaceType;
        attribute alert : AlertLevel;
        attribute runtimeRemaining : RuntimeEstimate;
    }

    // ---------- Port Definitions ----------

    port def AirPort {
        in air : AirFlow;
        out airOut : AirFlow;
    }

    port def DebrisPort {
        out debris : Debris;
    }

    port def PowerPort {
        in power : PowerSignal;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : StatusReport;
    }

    port def MechanicalDrivePort {
        out torque : Real;
        out speed : Frequency;
    }

    // ---------- Part Definitions ----------

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 22 [V];
        attribute capacity : BatteryCharge = 3000 [mAh];
        attribute currentCharge : BatteryCharge;
        attribute chargeCycles : Integer;
        attribute temperature : Temperature;

        port powerOut : PowerPort;

        exhibit state BatteryState {
            entry;
            state Charging {
                entry;
                transition to Charged
                    when currentCharge >= capacity;
            }
            state Charged {
                entry;
                transition to Discharging
                    when powerOut.power.current > 0 [A];
            }
            state Discharging {
                entry;
                transition to LowBattery
                    when currentCharge <= 0.15 * capacity;
                transition to Depleted
                    when currentCharge <= 0.02 * capacity;
            }
            state LowBattery {
                entry;
                transition to Depleted
                    when currentCharge <= 0.02 * capacity;
            }
            state Depleted {
                entry;
            }
        }

        compute dischargeRate : Power = powerOut.power.voltage * powerOut.power.current;
    }

    part def SuctionMotor {
        attribute maxRPM : MotorRPM = 125000 [rpm];
        attribute currentRPM : MotorRPM;
        attribute powerConsumption : Power;
        attribute mode : OperatingMode;

        port powerIn : PowerPort;
        port driveOut : MechanicalDrivePort;

        exhibit state MotorState {
            state Off {
                entry;
                transition to Running
                    when powerIn.power.current > 0 [A];
            }
            state Running {
                entry;
                transition to Off
                    when powerIn.power.current == 0 [A];
            }
        }

        compute rpmForMode : MotorRPM = (
            if mode == OperatingMode::eco then 60000 [rpm]
            else if mode == OperatingMode::normal then 90000 [rpm]
            else 125000 [rpm]
        );
    }

    part def ImpellerFan {
        attribute bladeCount : Integer = 9;
        attribute efficiency : Real = 0.85;
        attribute generatedSuction : SuctionPressure;
        attribute airflow : AirflowRate;

        port driveIn : MechanicalDrivePort;
        port airOut : AirPort;

        compute suctionGenerated : SuctionPressure = driveIn.speed * 0.0008 [Pa/rpm];
    }

    part def MotorizedBrushRoll {
        attribute brushSpeed : BrushSpeed;
        attribute enabled : Boolean;
        attribute bristleType : String;
        attribute wearLevel : Real;

        port driveIn : MechanicalDrivePort;

        exhibit state BrushState {
            state Stopped {
                entry;
                transition to Rotating
                    when enabled and driveIn.speed > 0 [rpm];
            }
            state Rotating {
                entry;
                transition to Stopped
                    when not enabled;
            }
        }

        compute effectiveSpeed : BrushSpeed = (
            if enabled then driveIn.speed else 0 [rpm]
        );
    }

    part def CleaningHead {
        attribute surfaceType : SurfaceType;
        attribute hasSurfaceSensor : Boolean = true;

        part brushRoll : MotorizedBrushRoll;
        part nozzle : Nozzle;

        port airConnection : AirPort;
        port controlIn : ControlPort;

        exhibit state HeadState {
            state Idle {
                entry;
                transition to Detecting
                    when controlIn.command.targetSurface != SurfaceType::hardFloor;
            }
            state Detecting {
                entry;
                transition to Active
                    when surfaceType != null;
            }
            state Active {
                entry;
            }
        }
    }

    part def Nozzle {
        attribute width : Real = 0.25 [m];
        attribute suctionArea : Real;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def DustChamber {
        attribute maxCapacity : DustLoad = 0.5 [kg];
        attribute currentLoad : DustLoad;
        attribute isFull : Boolean;

        port airIn : AirPort;
        port debrisOut : DebrisPort;
        port airOut : AirPort;

        exhibit state ChamberState {
            state Empty {
                entry;
                transition to PartiallyFilled
                    when currentLoad > 0 [kg];
            }
            state PartiallyFilled {
                entry;
                transition to Full
                    when currentLoad >= maxCapacity;
            }
            state Full {
                entry;
                transition to Empty
                    when currentLoad == 0 [kg];
            }
        }

        compute fillPercentage : Real = currentLoad / maxCapacity;
    }

    part def PreFilter {
        attribute poreSize : Real = 0.0005 [m];
        attribute captureEfficiency : Real = 0.80;
        attribute clogLevel : FilterClogLevel;
        attribute requiresMaintenance : Boolean;

        port airIn : AirPort;
        port airOut : AirPort;

        exhibit state FilterState {
            state Clean {
                entry;
                transition to Accumulating
                    when clogLevel > 0.0;
            }
            state Accumulating {
                entry;
                transition to Clogged
                    when clogLevel >= 0.7;
            }
            state Clogged {
                entry;
                transition to Clean
                    when requiresMaintenance == false;
            }
        }
    }

    part def HEPAFilter {
        attribute grade : String = "H13";
        attribute captureEfficiency : Real = 0.9995;
        attribute clogLevel : FilterClogLevel;
        attribute requiresMaintenance : Boolean;

        port airIn : AirPort;
        port airOut : AirPort;

        exhibit state HEPAState {
            state Operational {
                entry;
                transition to Degraded
                    when clogLevel >= 0.6;
            }
            state Degraded {
                entry;
                transition to Replaced
                    when requiresMaintenance;
            }
            state Replaced {
                entry;
                transition to Operational
                    when clogLevel == 0.0;
            }
        }
    }

    part def FiltrationSystem {
        part preFilter : PreFilter;
        part hepaFilter : HEPAFilter;

        port airIn : AirPort;
        port airOut : AirPort;

        connection preToHepa connect preFilter.airOut to hepaFilter.airIn;
        connection inToPre connect airIn to preFilter.airIn;
        connection hepatoOut connect hepaFilter.airOut to airOut;
    }

    part def ExhaustPort {
        attribute cleanAirFlow : AirflowRate;
        port airIn : AirPort;
    }

    part def SurfaceSensor {
        attribute detectedSurface : SurfaceType;
        attribute confidence : Real;

        port controlOut : ControlPort;

        compute detect : SurfaceType = (
            if confidence > 0.8 then detectedSurface
            else SurfaceType::hardFloor
        );
    }

    part def ControlModule {
        attribute selectedMode : OperatingMode = OperatingMode::normal;
        attribute detectedSurface : SurfaceType;
        attribute firmwareVersion : String = "2.1.0";
        attribute runtimeEstimate : RuntimeEstimate;

        part surfaceSensor : SurfaceSensor;

        port batteryMonitor : ControlPort;
        port motorControl : ControlPort;
        port brushControl : ControlPort;
        port dustMonitor : ControlPort;
        port filterMonitor : ControlPort;
        port userInterface : ControlPort;

        exhibit state ControllerState {
            state Booting {
                entry;
                transition to Idle
                    when firmwareVersion != null;
            }
            state Idle {
                entry;
                transition to Standby
                    when userInterface.command.targetMode != null;
            }
            state Standby {
                entry;
                transition to ActiveCleaning
                    when motorControl.command.powerLevel > 0;
                transition to Idle
                    when userInterface.command.targetMode == null;
            }
            state ActiveCleaning {
                entry;
                transition to Standby
                    when motorControl.command.powerLevel == 0;
                transition to Alerting
                    when batteryMonitor.status.alert == AlertLevel::critical
                        or dustMonitor.status.alert == AlertLevel::critical
                        or filterMonitor.status.alert == AlertLevel::critical;
            }
            state Alerting {
                entry;
                transition to Standby
                    when batteryMonitor.status.alert == AlertLevel::info;
            }
        }

        compute adjustedPower : Real = (
            if detectedSurface == SurfaceType::carpet then 1.0
            else if detectedSurface == SurfaceType::upholstery then 0.7
            else 0.5
        );

        compute adjustedBrushSpeed : BrushSpeed = (
            if detectedSurface == SurfaceType::carpet then 3500 [rpm]
            else if detectedSurface == SurfaceType::upholstery then 2000 [rpm]
            else 0 [rpm]
        );
    }

    part def UserInterface {
        attribute displayType : String = "LCD";
        attribute buttonCount : Integer = 3;
        attribute currentMode : OperatingMode;
        attribute currentAlert : AlertLevel;

        port controlOut : ControlPort;

        exhibit state UIState {
            state Off;
            state On {
                state DisplayingStatus;
                state DisplayingAlert;
                transition from DisplayingStatus to DisplayingAlert
                    when controlOut.status.alert != AlertLevel::info;
                transition from DisplayingAlert to DisplayingStatus
                    when controlOut.status.alert == AlertLevel::info;
            }
            transition from Off to On when true;
            transition from On to Off when false;
        }
    }

    // ---------- Top-Level Vacuum Cleaner ----------

    part def CordlessVacuumCleaner {
        attribute model : String = "VortexPro X1";
        attribute weight : Mass = 2.8 [kg];
        attribute color : String = "Midnight Blue";

        part battery : BatteryPack;
        part suctionMotor : SuctionMotor;
        part impellerFan : ImpellerFan;
        part cleaningHead : CleaningHead;
        part dustChamber : DustChamber;
        part filtrationSystem : FiltrationSystem;
        part exhaustPort : ExhaustPort;
        part controller : ControlModule;
        part userInterface : UserInterface;

        // Power connections
        connection batteryToMotor connect battery.powerOut to suctionMotor.powerIn;

        // Mechanical drive
        connection motorToFan connect suctionMotor.driveOut to impellerFan.driveIn;
        connection motorToBrush connect suctionMotor.driveOut to cleaningHead.brushRoll.driveIn;

        // Airflow path
        connection nozzleToChamber connect cleaningHead.nozzle.airOut to dustChamber.airIn;
        connection chamberToFiltration connect dustChamber.airOut to filtrationSystem.airIn;
        connection filtrationToExhaust connect filtrationSystem.airOut to exhaustPort.airIn;
        connection fanToHead connect impellerFan.airOut to cleaningHead.airConnection;

        // Control connections
        connection controllerToMotor connect controller.motorControl to suctionMotor.powerIn;
        connection controllerToBrush connect controller.brushControl to cleaningHead.controlIn;
        connection controllerToBattery connect controller.batteryMonitor to battery.powerOut;
        connection controllerToDust connect controller.dustMonitor to dustChamber.airOut;
        connection controllerToFilter connect controller.filterMonitor to filtrationSystem.airOut;
        connection controllerToUI connect controller.userInterface to userInterface.controlOut;
        connection sensorToController connect cleaningHead.controlIn to controller.surfaceSensor.controlOut;

        exhibit state VacuumOperationalState {
            state PoweredOff {
                entry;
                transition to Idle
                    when battery.currentCharge > 0 [mAh];
            }
            state Idle {
                entry;
                transition to Standby
                    when userInterface.controlOut.command.targetMode != null;
                transition to PoweredOff
                    when battery.currentCharge == 0 [mAh];
            }
            state Standby {
                entry;
                transition to ActiveCleaning
                    when suctionMotor.currentRPM > 0 [rpm];
                transition to Idle
                    when userInterface.controlOut.command.targetMode == null;
            }
            state ActiveCleaning {
                entry;
                transition to Standby
                    when suctionMotor.currentRPM == 0 [rpm];
                transition to MaintenanceRequired
                    when dustChamber.isFull
                        or filtrationSystem.preFilter.requiresMaintenance
                        or filtrationSystem.hepaFilter.requiresMaintenance;
                transition to LowBatteryMode
                    when battery.currentCharge <= 0.15 * battery.capacity;
            }
            state LowBatteryMode {
                entry;
                transition to PoweredOff
                    when battery.currentCharge <= 0.02 * battery.capacity;
                transition to ActiveCleaning
                    when battery.currentCharge > 0.15 * battery.capacity;
            }
            state MaintenanceRequired {
                entry;
                transition to ActiveCleaning
                    when not dustChamber.isFull
                        and not filtrationSystem.preFilter.requiresMaintenance
                        and not filtrationSystem.hepaFilter.requiresMaintenance;
            }
        }

        compute totalRuntime : RuntimeEstimate = battery.currentCharge / suctionMotor.powerConsumption;
        compute overallEfficiency : Real = filtrationSystem.hepaFilter.captureEfficiency * impellerFan.efficiency;
    }

    // ---------- Requirements ----------

    requirement def VacuumCleanerRequirements {

        requirement SuctionPerformance {
            doc "The vacuum shall generate sufficient suction to remove embedded dirt from carpets."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.impellerFan.generatedSuction >= 20000 [Pa] }
        }

        requirement BatteryRuntime {
            doc "The vacuum shall provide at least 40 minutes of runtime in eco mode."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.totalRuntime >= 40 [min] }
        }

        requirement FiltrationEfficiency {
            doc "The HEPA filter shall capture 99.95% of particles 0.3 microns or larger."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.filtrationSystem.hepaFilter.captureEfficiency >= 0.9995 }
        }

        requirement OperatingModes {
            doc "The vacuum shall support eco, normal, and turbo operating modes."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.controller.selectedMode in OperatingMode::eco..OperatingMode::turbo }
        }

        requirement SurfaceDetection {
            doc "The vacuum shall automatically detect surface type and adjust power and brush speed."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.cleaningHead.hasSurfaceSensor == true }
        }

        requirement DustChamberAlert {
            doc "The vacuum shall alert the user when the dust chamber reaches capacity."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.dustChamber.isFull implies vacuum.userInterface.currentAlert == AlertLevel::warning }
        }

        requirement FilterMaintenanceAlert {
            doc "The vacuum shall alert the user when filters require maintenance."
            subject vacuum : CordlessVacuumCleaner;
            constraint {
                (vacuum.filtrationSystem.preFilter.requiresMaintenance
                 or vacuum.filtrationSystem.hepaFilter.requiresMaintenance)
                implies vacuum.userInterface.currentAlert == AlertLevel::warning
            }
        }

        requirement LowBatteryAlert {
            doc "The vacuum shall alert the user when battery charge falls below 15%."
            subject vacuum : CordlessVacuumCleaner;
            constraint {
                vacuum.battery.currentCharge <= 0.15 * vacuum.battery.capacity
                implies vacuum.userInterface.currentAlert == AlertLevel::warning
            }
        }

        requirement Portability {
            doc "The vacuum shall weigh no more than 3.5 kg for portability."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.weight <= 3.5 [kg] }
        }

        requirement BrushRollAgitation {
            doc "The motorized brush roll shall agitate carpets at a minimum of 3000 RPM."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.cleaningHead.brushRoll.brushSpeed >= 3000 [rpm] }
        }

        requirement MultiStageFiltration {
            doc "The vacuum shall include a pre-filter and HEPA filter in series."
            subject vacuum : CordlessVacuumCleaner;
            constraint { vacuum.filtrationSystem.preFilter.poreSize > vacuum.filtrationSystem.hepaFilter.poreSize }
        }

        requirement StateManagement {
            doc "The vacuum shall operate in idle, standby, and active cleaning states."
            subject vacuum : CordlessVacuumCleaner;
            constraint {
                vacuum.VacuumOperationalState in {Idle, Standby, ActiveCleaning}
            }
        }
    }

    // ---------- Verification ----------

    verification SuctionPerformanceTest {
        subject vacuum : CordlessVacuumCleaner;
        objective { SuctionPerformance }
        method {
            vacuum.suctionMotor.currentRPM = 125000 [rpm];
            vacuum.impellerFan.driveIn.speed = vacuum.suctionMotor.currentRPM;
            assert vacuum.impellerFan.generatedSuction >= 20000 [Pa];
        }
    }

    verification RuntimeTest {
        subject vacuum : CordlessVacuumCleaner;
        objective { BatteryRuntime }
        method {
            vacuum.battery.currentCharge = 3000 [mAh];
            vacuum.controller.selectedMode = OperatingMode::eco;
            vacuum.suctionMotor.powerConsumption = 75 [W];
            assert vacuum.totalRuntime >= 40 [min];
        }
    }

    verification FiltrationTest {
        subject vacuum : CordlessVacuumCleaner;
        objective { FiltrationEfficiency }
        method {
            assert vacuum.filtrationSystem.hepaFilter.captureEfficiency >= 0.9995;
        }
    }

    verification PortabilityTest {
        subject vacuum : CordlessVacuumCleaner;
        objective { Portability }
        method {
            assert vacuum.weight <= 3.5 [kg];
        }
    }

}
