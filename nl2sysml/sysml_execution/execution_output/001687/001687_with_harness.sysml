package VacuumCleanerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def SuctionPowerValue :> PowerValue;
    attribute def AirflowRateValue :> VolumeFlowRateValue;
    attribute def FilterEfficiencyValue :> Real;
    attribute def NoiseLevel :> Real;

    enum def OperatingMode {
        off;
        eco;
        normal;
        turbo;
    }

    enum def SurfaceType {
        hardFloor;
        carpet;
        tile;
        upholstery;
    }

    item def Debris {
        attribute particleSize : LengthValue;
        attribute mass : MassValue;
    }

    item def DirtyAir {
        attribute debrisContent : MassValue;
    }

    item def CleanAir {
        attribute particleCount : Real;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def AirIntakePort {
        in item dirtyAir : DirtyAir;
    }

    port def AirExhaustPort {
        out item cleanAir : CleanAir;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    part def SuctionMotor {
        attribute ratedPower : PowerValue;
        attribute currentSpeed : Real;
        attribute maxSpeed : Real;
        attribute efficiency : Real;

        port powerIn : PowerInputPort;

        action def SpinUp {
            in targetSpeed : Real;
            out achievedSpeed : Real;
        }

        action def SpinDown {
            out finalSpeed : Real;
        }
    }

    part def ImpellerFan {
        attribute bladeCount : Integer;
        attribute diameter : LengthValue;
        attribute rotationSpeed : Real;

        action def GenerateAirflow {
            in motorSpeed : Real;
            out airflowRate : AirflowRateValue;
            out suctionPressure : PressureValue;
        }
    }

    part def DustChamber {
        attribute capacity : VolumeValue;
        attribute currentFillLevel : VolumeValue;
        attribute fillPercentage : Real;

        port debrisInlet {
            in item debris : Debris;
        }

        action def AccumulateDebris {
            in incomingDebris : MassValue;
            out newFillLevel : VolumeValue;
        }

        action def CheckCapacity {
            out isFull : Boolean;
        }
    }

    part def FiltrationSystem {
        attribute filterType : String;
        attribute efficiency : FilterEfficiencyValue;
        attribute cloggingLevel : Real;
        attribute needsMaintenance : Boolean;

        part preFilter {
            attribute meshSize : LengthValue;
        }

        part hepaFilter {
            attribute particleCaptureSize : LengthValue;
            attribute efficiency : Real = 0.997;
        }

        action def FilterAir {
            in dirtyAir : DirtyAir;
            out cleanAir : CleanAir;
            out capturedDebris : Debris;
        }

        action def MonitorClogging {
            in airflowResistance : PressureValue;
            out cloggingPercentage : Real;
        }
    }

    part def CleaningHead {
        attribute width : LengthValue;
        attribute heightAdjustment : LengthValue;
        attribute currentSurfaceType : SurfaceType;

        port airIntake : AirIntakePort;

        part brushRoll {
            attribute bristleLength : LengthValue;
            attribute rotationSpeed : Real;

            action def Agitate {
                in surface : SurfaceType;
                out dislodgedDebris : Debris;
            }
        }

        part suctionNozzle {
            attribute openingArea : AreaValue;

            action def IntakeDebris {
                in suctionPower : SuctionPowerValue;
                out collectedDebris : Debris;
            }
        }
    }

    part def ControlModule {
        attribute selectedMode : OperatingMode;
        attribute powerLevel : Real;
        attribute batteryCharge : Real;
        attribute systemStatus : String;

        action def SelectMode {
            in userInput : OperatingMode;
            out targetPowerLevel : Real;
        }

        action def MonitorSystem {
            in dustLevel : VolumeValue;
            in filterStatus : Real;
            in batteryLevel : Real;
            out statusReport : String;
            out warningFlag : Boolean;
        }

        action def AdjustPower {
            in mode : OperatingMode;
            in surfaceDetected : SurfaceType;
            out motorPower : PowerValue;
        }
    }

    part def BatteryPack {
        attribute capacity : Real;
        attribute voltage : ElectricPotentialValue;
        attribute currentCharge : Real;
        attribute chargePercentage : Real;

        port powerOutput : PowerInputPort;

        action def SupplyPower {
            in powerDemand : PowerValue;
            out deliveredPower : PowerValue;
            out remainingCharge : Real;
        }

        action def MonitorCharge {
            out chargeLevel : Real;
            out lowBatteryWarning : Boolean;
        }
    }

    action def VacuumCleaningOperation {
        doc /* Primary cleaning operation that removes debris from surfaces
             * through suction, separation, filtration, and exhaust. */

        first start;
        then merge continueCleaning;

        then action initializeSystem {
            doc /* Power on and perform system checks. */
            out systemReady : Boolean;
        }

        then action detectSurface {
            doc /* Identify the type of surface being cleaned. */
            out surfaceType : SurfaceType;
        }

        then action configurePower {
            doc /* Adjust motor power based on mode and surface. */
            in surface = detectSurface.surfaceType;
            out powerSetting : PowerValue;
        }

        then action activateMotor {
            doc /* Start the suction motor at configured power. */
            in power = configurePower.powerSetting;
            out motorRunning : Boolean;
        }

        then action generateSuction {
            doc /* Fan creates airflow and negative pressure. */
            in motorActive = activateMotor.motorRunning;
            out suctionActive : Boolean;
            out airflowRate : AirflowRateValue;
        }

        then action agitateSurface {
            doc /* Brush roll loosens embedded debris. */
            in surface = detectSurface.surfaceType;
            out debrisLoosened : Boolean;
        }

        then action intakeDebrisAndAir {
            doc /* Nozzle draws in debris-laden air. */
            in suction = generateSuction.suctionActive;
            in agitation = agitateSurface.debrisLoosened;
            out debrisIntaken : Boolean;
        }

        then action separateDebris {
            doc /* Cyclonic action separates debris from airstream. */
            in intakeActive = intakeDebrisAndAir.debrisIntaken;
            out debrisSeparated : Boolean;
        }

        then action collectDebris {
            doc /* Separated debris accumulates in dust chamber. */
            in separated = separateDebris.debrisSeparated;
            out debrisStored : Boolean;
        }

        then action filterAir {
            doc /* Multi-stage filtration removes fine particles. */
            in airflow = generateSuction.airflowRate;
            out airFiltered : Boolean;
        }

        then action exhaustCleanAir {
            doc /* Filtered air expelled back to environment. */
            in filtered = filterAir.airFiltered;
            out airExhausted : Boolean;
        }

        then action monitorStatus {
            doc /* Check system health and capacity. */
            out dustBinFull : Boolean;
            out filterClogged : Boolean;
            out batteryLow : Boolean;
        }

        then decide;
            if monitorStatus.dustBinFull or monitorStatus.filterClogged then requireMaintenance;
            if monitorStatus.batteryLow then shutdownLowBattery;
            if !monitorStatus.dustBinFull and !monitorStatus.filterClogged and !monitorStatus.batteryLow then continueCleaning;

        action requireMaintenance {
            doc /* Alert user and pause operation. */
        }
        then done;

        action shutdownLowBattery {
            doc /* Safe shutdown due to battery depletion. */
        }
        then done;
    }

    part def VacuumCleaner {
        attribute totalMass : MassValue;
        attribute maxSuctionPower : SuctionPowerValue;
        attribute noiseLevel : NoiseLevel;
        attribute operationalRuntime : DurationValue;

        port mainPowerInput : PowerInputPort;
        port exhaustPort : AirExhaustPort;

        part motor : SuctionMotor {
            attribute ratedPower : PowerValue = 850 [W];
            attribute maxSpeed : Real = 28000.0;
            attribute efficiency : Real = 0.85;
        }

        part fan : ImpellerFan {
            attribute bladeCount : Integer = 8;
            attribute diameter : LengthValue = 75 [mm];
        }

        part dustBin : DustChamber {
            attribute capacity : VolumeValue = 0.6 [L];
            attribute currentFillLevel : VolumeValue = 0.0 [L];
        }

        part filtration : FiltrationSystem {
            attribute filterType : String = "HEPA H13";
            attribute efficiency : FilterEfficiencyValue = 0.995;
        }

        part cleaningHead : CleaningHead {
            attribute width : LengthValue = 280 [mm];
        }

        part controller : ControlModule {
            attribute selectedMode : OperatingMode = OperatingMode::normal;
            attribute batteryCharge : Real = 100.0;
        }

        part battery : BatteryPack {
            attribute capacity : Real = 3000.0;
            attribute voltage : ElectricPotentialValue = 25.2 [V];
            attribute chargePercentage : Real = 100.0;
        }

        connection batteryToMotor connect battery.powerOutput to motor.powerIn;
        connection motorToFan connect motor to fan;
        connection headToIntake connect cleaningHead.airIntake to dustBin.debrisInlet;
        connection dustBinToFilter connect dustBin to filtration;
        connection filterToExhaust connect filtration to exhaustPort;

        perform action operateVacuum : VacuumCleaningOperation;

        state machine VacuumOperatingStates {
            state Idle;
            state Standby;
            state Cleaning;
            state MaintenanceRequired;
            state BatteryDepleted;

            transition idleToStandby
                first Idle
                accept at controller
                then Standby;

            transition standbyToCleaning
                first Standby
                accept at controller
                then Cleaning;

            transition cleaningToMaintenance
                first Cleaning
                accept at dustBin
                then MaintenanceRequired;

            transition cleaningToBatteryDepleted
                first Cleaning
                accept at battery
                then BatteryDepleted;

            transition maintenanceToStandby
                first MaintenanceRequired
                accept at controller
                then Standby;

            transition batteryDepletedToIdle
                first BatteryDepleted
                accept at battery
                then Idle;

            transition cleaningToStandby
                first Cleaning
                accept at controller
                then Standby;
        }
    }

    requirement <'REQ-VC-100'> primaryCleaningFunction {
        doc /* The vacuum cleaner shall remove dirt, dust, and debris from 
             * various surfaces by generating suction that draws debris-laden air 
             * into the system, separating and collecting solid particles, 
             * filtering the air to capture fine particulates, and exhausting 
             * clean air back into the environment. */
        
        subject vacuumCleaner : VacuumCleaner;

        require <'REQ-VC-101'> suctionPerformance {
            doc /* The system shall generate minimum suction power to effectively 
                 * lift debris from surfaces. */
            assert constraint {
                vacuumCleaner.maxSuctionPower >= 120 [W]
            }
        }

        require <'REQ-VC-102'> filtrationEfficiency {
            doc /* The filtration system shall capture at least 99.5% of particles 
                 * to prevent recontamination. */
            assert constraint {
                vacuumCleaner.filtration.efficiency >= 0.995
            }
        }

        require <'REQ-VC-103'> debrisCapacity {
            doc /* The dust chamber shall provide adequate storage for collected debris. */
            assert constraint {
                vacuumCleaner.dustBin.capacity >= 0.5 [L]
            }
        }

        require <'REQ-VC-104'> operationalRuntime {
            doc /* The system shall operate continuously for minimum duration 
                 * on a single battery charge. */
            assert constraint {
                vacuumCleaner.operationalRuntime >= 30 [min]
            }
        }

        require <'REQ-VC-105'> portability {
            doc /* The system shall be lightweight for user mobility. */
            assert constraint {
                vacuumCleaner.totalMass <= 2.5 [kg]
            }
        }
    }

    part vacuumCleanerInstance : VacuumCleaner {
        attribute totalMass : MassValue = 2.3 [kg];
        attribute maxSuctionPower : SuctionPowerValue = 150 [W];
        attribute noiseLevel : NoiseLevel = 72.0;
        attribute operationalRuntime : DurationValue = 35 [min];
    }

    satisfy primaryCleaningFunction by vacuumCleanerInstance;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import VacuumCleanerSystem::*;

    action orchestrator {
        action actionProbe : SpinUp {
            in targetSpeed = 0.0;
        }
        first actionProbe;
    }
}
