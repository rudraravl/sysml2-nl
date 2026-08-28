package NuclearDensityGauge {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type DensityValue :> Real {
        unit kg/m^3;
    }
    value type MoistureValue :> Real {
        unit kg/m^3;
    }
    value type CountRate :> Real {
        unit counts/s;
    }
    value type Voltage :> Real {
        unit V;
    }
    value type TimeDuration :> Real {
        unit s;
    }
    value type DepthValue :> Real {
        unit m;
    }
    value type ActivityValue :> Real {
        unit MBq;
    }

    // ===== Enumerations =====
    enum MeasurementMode {
        directTransmission;
        backscatter;
    }

    enum ShutterPosition {
        closed;
        open;
    }

    enum InterlockState {
        locked;
        armed;
        fault;
    }

    enum MaterialType {
        soil;
        asphalt;
        compactedBase;
    }

    // ===== Item Types =====
    item def GammaRay;
    item def ScatteredGammaRay :> GammaRay;
    item def TransmittedGammaRay :> GammaRay;
    item def DetectorPulse;
    item def ProcessedSignal;
    item def MeasurementResult {
        attribute density : DensityValue;
        attribute moisture : MoistureValue;
        attribute mode : MeasurementMode;
        attribute depth : DepthValue;
        attribute material : MaterialType;
        attribute timestamp : String;
    }
    item def CalibrationParameters {
        attribute densityCalFactor : Real;
        attribute moistureCalFactor : Real;
        attribute densityOffset : Real;
        attribute moistureOffset : Real;
    }
    item def UserCommand {
        attribute commandType : String;
        attribute depth : DepthValue;
        attribute mode : MeasurementMode;
        attribute material : MaterialType;
    }
    item def ArmingCode {
        attribute codeValue : String;
    }

    // ===== Port Definitions =====
    port def GammaEmissionPort {
        out item gammaRay : GammaRay;
    }
    port def GammaDetectionPort {
        in item incidentGamma : GammaRay;
    }
    port def PulsePort {
        out item pulse : DetectorPulse;
    }
    port def SignalPort {
        in item inputSignal : DetectorPulse;
        out item outputSignal : ProcessedSignal;
    }
    port def DataPort {
        in item processedSignal : ProcessedSignal;
        out item result : MeasurementResult;
    }
    port def CommandPort {
        in item command : UserCommand;
        out item result : MeasurementResult;
    }
    port def InterlockPort {
        out item shutterCommand : ShutterPosition;
        in item shutterStatus : ShutterPosition;
    }
    port def ShutterControlPort {
        in item command : ShutterPosition;
        out item status : ShutterPosition;
    }

    // ===== Requirements =====
    requirement def Id01_DensityMeasurement {
        subject gauge : NuclearDensityGauge;
        doc /* The gauge shall measure material density in kg/m^3. */
        attribute targetAccuracy : DensityValue = 16.0;
        require gauge.measuredDensity.accuracy <= targetAccuracy;
    }

    requirement def Id02_MoistureMeasurement {
        subject gauge : NuclearDensityGauge;
        doc /* The gauge shall measure moisture content in kg/m^3. */
        attribute targetAccuracy : MoistureValue = 8.0;
        require gauge.measuredMoisture.accuracy <= targetAccuracy;
    }

    requirement def Id03_ShutterAutoClose {
        subject gauge : NuclearDensityGauge;
        doc /* The shutter shall automatically close upon measurement completion. */
        require gauge.shutter.autoCloseOnCompletion == true;
    }

    requirement def Id04_InterlockArming {
        subject gauge : NuclearDensityGauge;
        doc /* The shutter shall remain locked unless an authorized code is entered. */
        require gauge.interlock.requiresAuthorizedCode == true;
    }

    requirement def Id05_RadiationShielding {
        subject gauge : NuclearDensityGauge;
        doc /* The shield shall limit operator dose to safe levels. */
        attribute maxDoseRate : Real = 2.0; // uSv/h at 1 m
        require gauge.shield.surfaceDoseRate <= maxDoseRate;
    }

    requirement def Id06_MeasurementModes {
        subject gauge : NuclearDensityGauge;
        doc /* The gauge shall support direct transmission and backscatter modes. */
        require gauge.supportedModes == {MeasurementMode::directTransmission, MeasurementMode::backscatter};
    }

    // ===== Parts =====
    part def SealedSource {
        attribute isotope : String = "Cesium-137";
        attribute activity : ActivityValue = 370.0;
        attribute sealed : Boolean = true;
        port emissionPort : GammaEmissionPort;
    }

    part def RadiationShield {
        attribute material : String = "tungsten";
        attribute thickness : Real = 50.0; // mm
        attribute surfaceDoseRate : Real = 1.5; // uSv/h at 1 m
        attribute shutterAutoCloseOnCompletion : Boolean = true;
        port shutterControl : ShutterControlPort;
        port emissionPort : GammaEmissionPort;
    }

    part def MechanicalShutter {
        attribute position : ShutterPosition = ShutterPosition::closed;
        attribute maxOpenDuration : TimeDuration = 60.0;
        port control : ShutterControlPort;
        exhibit state ShutterStateMachine {
            entry; then Closed;
            state Closed {
                on control.command(ShutterPosition::open) if control.command == ShutterPosition::open
                    transition to Opening;
            }
            state Opening {
                entry assign position = ShutterPosition::open;
                then Open;
            }
            state Open {
                on control.command(ShutterPosition::closed)
                    transition to Closing;
            }
            state Closing {
                entry assign position = ShutterPosition::closed;
                then Closed;
            }
        }
    }

    part def SourceRod {
        attribute extended : Boolean = false;
        attribute maxDepth : DepthValue = 0.30;
        attribute currentDepth : DepthValue = 0.0;
        action def ExtendRod(in depth : DepthValue) {
            assign extended = true;
            assign currentDepth = depth;
        }
        action def RetractRod() {
            assign extended = false;
            assign currentDepth = 0.0;
        }
    }

    part def ScintillationDetector {
        attribute detectorType : String = "NaI(Tl)";
        attribute sensitivity : Real = 0.85;
        port detectionPort : GammaDetectionPort;
        port pulsePort : PulsePort;
        exhibit state DetectionOperation {
            entry; then Idle;
            state Idle {
                on detectionPort.incidentGamma
                    transition to Detecting;
            }
            state Detecting {
                entry; then EmitPulse;
                do send pulsePort.pulse();
                transition to Idle;
            }
            state EmitPulse;
        }
    }

    part def SignalProcessor {
        attribute gain : Real = 100.0;
        attribute threshold : Voltage = 0.05;
        port signalPort : SignalPort;
        action def ProcessPulse(in pulse : DetectorPulse) : ProcessedSignal {
            // Amplify and shape pulse
        }
    }

    part def ComputationUnit {
        attribute calibration : CalibrationParameters;
        attribute measuredDensity : DensityValue;
        attribute measuredMoisture : MoistureValue;
        port dataPort : DataPort;
        action def ComputeResults(in signal : ProcessedSignal, in params : CalibrationParameters) : MeasurementResult {
            // Convert count rate to density and moisture using calibration
        }
        action def AccumulateCounts(in signal : ProcessedSignal) : CountRate {
            // Integrate pulses over measurement interval
        }
    }

    part def UserInterface {
        attribute displayType : String = "LCD";
        attribute keypadEnabled : Boolean = true;
        port commandPort : CommandPort;
        action def DisplayResults(in result : MeasurementResult) {
            // Show density, moisture, mode, depth on display
        }
        action def ReceiveCommand() : UserCommand {
            // Operator input via control panel
        }
    }

    part def SafetyInterlock {
        attribute state : InterlockState = InterlockState::locked;
        attribute requiresAuthorizedCode : Boolean = true;
        attribute authorizedCode : String = "12345";
        attribute activeMeasurement : Boolean = false;
        port interlockPort : InterlockPort;
        exhibit state InterlockStateMachine {
            entry; then Locked;
            state Locked {
                on ArmRequest
                    if enteredCode == authorizedCode
                    transition to Armed;
            }
            state Armed {
                on MeasurementStart
                    transition to Active;
                on Disarm
                    transition to Locked;
            }
            state Active {
                entry assign activeMeasurement = true;
                send interlockPort.shutterCommand(ShutterPosition::open);
                on MeasurementComplete {
                    send interlockPort.shutterCommand(ShutterPosition::closed);
                    transition to Armed;
                }
                on Fault {
                    send interlockPort.shutterCommand(ShutterPosition::closed);
                    transition to Faulted;
                }
            }
            state Faulted {
                entry assign state = InterlockState::fault;
                send interlockPort.shutterCommand(ShutterPosition::closed);
            }
        }
    }

    part def PowerSupply {
        attribute batteryType : String = "Li-ion";
        attribute capacity : Real = 7.2; // Ah
        attribute voltage : Voltage = 12.0;
        attribute chargeLevel : Real = 100.0; // percent
    }

    // ===== Top-level System =====
    part def NuclearDensityGauge {
        attribute supportedModes : MeasurementMode[2] = {MeasurementMode::directTransmission, MeasurementMode::backscatter};
        attribute measuredDensity : DensityValue;
        attribute measuredMoisture : MoistureValue;
        attribute currentMode : MeasurementMode = MeasurementMode::backscatter;
        attribute currentDepth : DepthValue = 0.0;
        attribute currentMaterial : MaterialType = MaterialType::soil;

        satisfy Id01_DensityMeasurement;
        satisfy Id02_MoistureMeasurement;
        satisfy Id03_ShutterAutoClose;
        satisfy Id04_InterlockArming;
        satisfy Id05_RadiationShielding;
        satisfy Id06_MeasurementModes;

        part sealedSource : SealedSource;
        part shield : RadiationShield;
        part shutter : MechanicalShutter;
        part sourceRod : SourceRod;
        part detector : ScintillationDetector;
        part signalProcessor : SignalProcessor;
        part computationUnit : ComputationUnit;
        part userInterface : UserInterface;
        part interlock : SafetyInterlock;
        part powerSupply : PowerSupply;

        connection def GammaBeamConnection {
            end sourceEmission : GammaEmissionPort;
            end detectorIncident : GammaDetectionPort;
        }

        connection gammaPath : GammaBeamConnection connect
            sealedSource.emissionPort to detector.detectionPort;

        connection shutterControlLink connect
            interlock.interlockPort to shield.shutterControl;

        connection shieldShutterLink connect
            shield.shutterControl to shutter.control;

        connection pulseLink connect
            detector.pulsePort to signalProcessor.signalPort;

        connection processedSignalLink connect
            signalProcessor.signalPort to computationUnit.dataPort;

        connection resultLink connect
            computationUnit.dataPort to userInterface.commandPort;

        connection interlockFeedbackLink connect
            shutter.control to interlock.interlockPort;

        action def PerformMeasurement(in command : UserCommand) : MeasurementResult {
            // Validate user command and arming
            // Configure mode and depth
            // Open shutter via interlock
            // Accumulate detector counts
            // Compute density and moisture
            // Close shutter
            // Return result
        }

        exhibit state GaugeOperation {
            entry; then PoweredOff;
            state PoweredOff {
                on PowerOn transition to Standby;
            }
            state Standby {
                on TestInitiated transition to Arming;
            }
            state Arming {
                on CodeAccepted transition to Ready;
                on CodeRejected transition to Standby;
            }
            state Ready {
                on MeasurementStart transition to Measuring;
            }
            state Measuring {
                entry assign currentMode = userInterface.commandPort.command.mode;
                entry assign currentDepth = userInterface.commandPort.command.depth;
                entry assign currentMaterial = userInterface.commandPort.command.material;
                // Shutter opens, counts accumulate, computation runs
                on MeasurementComplete transition to ResultsDisplay;
            }
            state ResultsDisplay {
                // Display results on UI
                on Acknowledge transition to Ready;
                on PowerOff transition to PoweredOff;
            }
        }
    }

    // ===== Instance =====
    part gaugeInstance : NuclearDensityGauge {
        attribute serialNumber : String = "NDG-2024-001";
        attribute firmwareVersion : String = "v3.2.1";
    }
}
