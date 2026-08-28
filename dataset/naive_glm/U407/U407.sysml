package SterileSurgicalLubricantDeliverySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SIUnits::*;

    // ===== Value Types =====

    value type ViscosityValue :> Real {
        doc "Dynamic viscosity of lubricant gel, expressed in Pascal-seconds (Pa·s).";
    }

    value type TemperatureValue :> Real {
        doc "Temperature expressed in Kelvin (K).";
        :>> unit = kelvin;
    }

    value type FlowRateValue :> Real {
        doc "Volume flow rate expressed in milliliters per minute (mL/min).";
    }

    value type VolumeValue :> Real {
        doc "Volume expressed in milliliters (mL).";
    }

    value type FrictionCoefficientValue :> Real {
        doc "Dimensionless coefficient of surface friction.";
        :>> unit = 1;
    }

    value type PressureValue :> Real {
        doc "Pressure expressed in Pascals (Pa).";
        :>> unit = pascal;
    }

    value type PowerValue :> Real {
        doc "Electrical or thermal power expressed in Watts (W).";
        :>> unit = watt;
    }

    value type RotationalSpeedValue :> Real {
        doc "Rotational speed expressed in radians per second (rad/s).";
    }

    value type DiameterValue :> Real {
        doc "Diameter expressed in millimeters (mm).";
    }

    value type AngleValue :> Real {
        doc "Angle expressed in degrees.";
    }

    value type PercentageValue :> Real {
        doc "Percentage value from 0 to 100.";
    }

    // ===== Enumerations =====

    enum DispenseMode {
        operatorControlled;
        programControlled;
    }

    enum ProcedureType {
        laparoscopy;
        openSurgery;
        endoscopy;
        arthroscopy;
    }

    enum ApplicationTarget {
        instrument;
        tissueSurface;
    }

    enum AlertLevel {
        nominal;
        warning;
        critical;
    }

    // ===== Item Definitions =====

    item def LubricantGel {
        doc "Sterile, water-soluble, biocompatible surgical lubricating gel.";
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
        attribute isSterile : Boolean;
        attribute isBiocompatible : Boolean;
        attribute isWaterSoluble : Boolean;
        attribute batchIdentifier : String;
        attribute expiryDate : String;

        constraint sterilityConstraint { isSterile == true }
        constraint biocompatibilityConstraint { isBiocompatible == true }
        constraint waterSolubilityConstraint { isWaterSoluble == true }
        constraint viscosityRangeConstraint { viscosity >= 0.5 and viscosity <= 5.0 }
        constraint bodyTemperatureConstraint { temperature >= 309.15 and temperature <= 313.15 }
    }

    item def AppliedLubricant :> LubricantGel {
        doc "Lubricant gel that has been applied to a target surface.";
        attribute applicationTarget : ApplicationTarget;
        attribute appliedVolume : VolumeValue;
        attribute coverageArea : Real;
    }

    // ===== Port Definitions =====

    port def FluidPort {
        item flow : LubricantGel;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def ControlSignalPort {
        attribute commandedFlowRate : FlowRateValue;
        attribute actualFlowRate : FlowRateValue;
        attribute dispenseMode : DispenseMode;
        attribute dispenseCommand : Boolean;
        attribute stopCommand : Boolean;
    }

    port def MonitoringPort {
        attribute measuredViscosity : ViscosityValue;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredFriction : FrictionCoefficientValue;
        attribute measuredFlowRate : FlowRateValue;
        attribute measuredVolume : VolumeValue;
        attribute alertLevel : AlertLevel;
    }

    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : PowerValue;
    }

    // ===== Action Definitions =====

    action def Initialize {
        doc "Initialize the system for a surgical procedure.";
        out ready : Boolean;
    }

    action def Prime {
        doc "Prime all fluid lines with lubricant for immediate dispensing.";
        in gel : LubricantGel;
        out primed : Boolean;
    }

    action def Dispense {
        doc "Dispense lubricant at the target flow rate.";
        in flowRate : FlowRateValue;
        in mode : DispenseMode;
        in target : ApplicationTarget;
        out dispensedVolume : VolumeValue;
    }

    action def MonitorLubricant {
        doc "Continuously monitor lubricant properties during operation.";
        out viscosity : ViscosityValue;
        out temperature : TemperatureValue;
        out flowRate : FlowRateValue;
        out friction : FrictionCoefficientValue;
    }

    action def AdjustTemperature {
        doc "Adjust lubricant temperature to maintain optimal performance.";
        in targetTemperature : TemperatureValue;
    }

    action def MeasureFriction {
        doc "Measure surface friction to evaluate effectiveness.";
        in target : ApplicationTarget;
        out friction : FrictionCoefficientValue;
    }

    action def CalibrateBaseline {
        doc "Calibrate baseline friction before lubricant application.";
        in target : ApplicationTarget;
        out baseline : FrictionCoefficientValue;
    }

    action def EvaluateEffectiveness {
        doc "Evaluate friction reduction effectiveness.";
        in baselineFriction : FrictionCoefficientValue;
        in currentFriction : FrictionCoefficientValue;
        out reduction : FrictionCoefficientValue;
        out reductionPercentage : PercentageValue;
    }

    action def Shutdown {
        doc "Safely shut down the system after procedure completion.";
        out completed : Boolean;
    }

    // ===== Part Definitions =====

    part def LubricantCartridge {
        doc "Disposable, pre-filled cartridge containing sterile lubricant gel.";
        attribute fillVolume : VolumeValue;
        attribute remainingVolume : VolumeValue;
        attribute isDisposable : Boolean;
        attribute isPreFilled : Boolean;
        attribute containedGel : LubricantGel;
        port fluidOut : FluidPort;

        constraint fillCapacityConstraint { fillVolume >= 100.0 }
        constraint remainingNonNegative { remainingVolume >= 0.0 }
        constraint disposableConstraint { isDisposable == true }
        constraint preFilledConstraint { isPreFilled == true }

        action dispenseGel {
            doc "Dispense specified amount of gel from cartridge.";
            in amount : VolumeValue;
            out dispensedGel : LubricantGel;
        }

        action checkRemaining {
            doc "Check remaining lubricant volume in cartridge.";
            out remaining : VolumeValue;
        }
    }

    part def PrecisionPump {
        doc "Precision pump mechanism for drawing lubricant from cartridge and pushing it through the system.";
        attribute maxFlowRate : FlowRateValue;
        attribute currentFlowRate : FlowRateValue;
        attribute pumpSpeed : RotationalSpeedValue;
        attribute isRunning : Boolean;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlSignal : ControlSignalPort;
        port powerIn : PowerPort;

        constraint maxFlowCapacity { maxFlowRate >= 10.0 }
        constraint flowNonNegative { currentFlowRate >= 0.0 }

        action pumpLubricant {
            doc "Draw lubricant from inlet and push to outlet at controlled rate.";
            in gel : LubricantGel;
            out gelOut : LubricantGel;
        }

        action adjustPumpSpeed {
            doc "Adjust pump speed to achieve target flow rate.";
            in targetFlowRate : FlowRateValue;
        }

        action startPump {
            doc "Start the pump mechanism.";
        }

        action stopPump {
            doc "Stop the pump mechanism.";
        }
    }

    part def ElectronicFlowController {
        doc "Electronic flow controller ensuring precise and stable dispensing rate.";
        attribute targetFlowRate : FlowRateValue;
        attribute tolerance : FlowRateValue;
        attribute dispenseMode : DispenseMode;
        attribute isProgramActive : Boolean;
        attribute programFlowRates : FlowRateValue[0..*];
        port pumpControl : ControlSignalPort;
        port monitoring : MonitoringPort;
        port uiControl : ControlSignalPort;

        constraint flowStability {
            pumpControl.actualFlowRate >= targetFlowRate - tolerance and
            pumpControl.actualFlowRate <= targetFlowRate + tolerance
        }

        action regulateFlow {
            doc "Regulate pump to achieve target flow rate.";
            in target : FlowRateValue;
            in actual : FlowRateValue;
            out command : FlowRateValue;
        }

        action executeProgram {
            doc "Execute a pre-set dispensing program.";
            in programId : String;
        }

        action switchMode {
            doc "Switch between operator-controlled and program-controlled modes.";
            in mode : DispenseMode;
        }
    }

    part def TemperatureModule {
        doc "Module to adjust and maintain lubricant temperature at body temperature for optimal performance.";
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute heaterPower : PowerValue;
        attribute maxPower : PowerValue;
        attribute isActive : Boolean;
        port monitoring : MonitoringPort;

        constraint temperatureRange {
            currentTemperature >= 309.15 and currentTemperature <= 313.15
        }
        constraint powerLimit { heaterPower <= maxPower }

        action adjustTemperature {
            doc "Heat or cool lubricant to target temperature.";
            in target : TemperatureValue;
        }

        action readTemperature {
            doc "Read current lubricant temperature.";
            out temperature : TemperatureValue;
        }
    }

    part def ViscositySensor {
        doc "Sensor to continuously monitor lubricant viscosity during operation.";
        attribute measuredViscosity : ViscosityValue;
        attribute samplingRate : Real;
        attribute minViscosity : ViscosityValue;
        attribute maxViscosity : ViscosityValue;
        port monitoring : MonitoringPort;

        action measureViscosity {
            doc "Measure current viscosity of lubricant gel.";
            in gel : LubricantGel;
            out viscosity : ViscosityValue;
        }

        action checkOutOfRange {
            doc "Check if viscosity is outside acceptable range.";
            out outOfRange : Boolean;
        }
    }

    part def FrictionSensor {
        doc "Sensor to measure surface friction and evaluate lubrication effectiveness.";
        attribute measuredFriction : FrictionCoefficientValue;
        attribute baselineFriction : FrictionCoefficientValue;
        attribute currentFriction : FrictionCoefficientValue;
        attribute maxAllowedFriction : FrictionCoefficientValue;
        port monitoring : MonitoringPort;

        action measureFriction {
            doc "Measure current friction coefficient on target surface.";
            in target : ApplicationTarget;
            out friction : FrictionCoefficientValue;
        }

        action calibrateBaseline {
            doc "Calibrate baseline friction before lubricant application.";
            in target : ApplicationTarget;
            out baseline : FrictionCoefficientValue;
        }

        action checkExceedsLimit {
            doc "Check if current friction exceeds the allowed limit.";
            out exceeds : Boolean;
        }
    }

    part def ApplicationNozzle {
        doc "Specialized application nozzle with tapered tip for accurate delivery to instruments or tissue surfaces.";
        attribute tipDiameter : DiameterValue;
        attribute taperAngle : AngleValue;
        attribute isSterile : Boolean;
        attribute flowResistance : PressureValue;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        constraint tipDiameterRange { tipDiameter >= 0.5 and tipDiameter <= 5.0 }
        constraint nozzleSterility { isSterile == true }

        action applyLubricant {
            doc "Apply lubricant gel to instrument or tissue surface.";
            in gel : LubricantGel;
            in target : ApplicationTarget;
            out appliedGel : AppliedLubricant;
        }
    }

    part def UserInterface {
        doc "Operator interface for commanding the system and viewing status during surgical procedures.";
        attribute currentMode : DispenseMode;
        attribute targetFlowRate : FlowRateValue;
        attribute displayStatus : String;
        attribute alertLevel : AlertLevel;
        port monitoring : MonitoringPort;
        port control : ControlSignalPort;

        action setFlowRate {
            doc "Operator sets desired flow rate.";
            in rate : FlowRateValue;
        }

        action selectProgram {
            doc "Operator selects a pre-set dispensing program.";
            in programId : String;
        }

        action setDispenseMode {
            doc "Switch between operator and program control.";
            in mode : DispenseMode;
        }

        action displayAlert {
            doc "Display alert or status message to operator.";
            in message : String;
            in level : AlertLevel;
        }

        action startDispensing {
            doc "Operator commands dispensing to begin.";
        }

        action stopDispensing {
            doc "Operator commands dispensing to stop.";
        }
    }

    part def PowerSupply {
        doc "Power supply providing electrical energy to system components.";
        attribute outputPower : PowerValue;
        attribute maxPower : PowerValue;
        attribute isOn : Boolean;
        port powerOut : PowerPort;

        constraint powerCapacity { maxPower >= 100.0 }

        action supplyPower {
            doc "Supply electrical power to system components.";
            in demand : PowerValue;
        }

        action activate {
            doc "Turn on the power supply.";
        }

        action deactivate {
            doc "Turn off the power supply.";
        }
    }

    // ===== Connection Definitions =====

    connection def FluidConnection {
        end source : FluidPort;
        end target : FluidPort;
    }

    connection def ControlConnection {
        end source : ControlSignalPort;
        end target : ControlSignalPort;
    }

    connection def MonitoringConnection {
        end source : MonitoringPort;
        end target : MonitoringPort;
    }

    connection def PowerConnection {
        end source : PowerPort;
        end target : PowerPort;
    }

    // ===== Main System =====

    part def SurgicalLubricantSystem {
        doc "Sterile Surgical Lubricant Delivery System for automatic application of biocompatible lubricant in operating rooms.";

        attribute systemIdentifier : String;
        attribute procedureType : ProcedureType;
        attribute targetFlowRate : FlowRateValue;
        attribute currentViscosity : ViscosityValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentFriction : FrictionCoefficientValue;
        attribute baselineFriction : FrictionCoefficientValue;
        attribute frictionReduction : FrictionCoefficientValue;
        attribute frictionReductionPercent : PercentageValue;
        attribute isPrimed : Boolean;
        attribute isOperating : Boolean;
        attribute totalDispensedVolume : VolumeValue;

        // Trigger and status signals
        attribute systemActivated : Boolean;
        attribute primingComplete : Boolean;
        attribute primingFailure : Boolean;
        attribute dispenseCommandReceived : Boolean;
        attribute dispensingCycleComplete : Boolean;
        attribute continueDispensingFlag : Boolean;
        attribute dispenseStopped : Boolean;
        attribute frictionExceedsLimit : Boolean;
        attribute viscosityOutOfRange : Boolean;
        attribute systemReset : Boolean;

        part cartridge : LubricantCartridge {
            :>> fillVolume = 250.0;
            :>> remainingVolume = 250.0;
            :>> isDisposable = true;
            :>> isPreFilled = true;
            :>> containedGel : LubricantGel {
                :>> viscosity = 2.0;
                :>> temperature = 310.15;
                :>> volume = 250.0;
                :>> isSterile = true;
                :>> isBiocompatible = true;
                :>> isWaterSoluble = true;
                :>> batchIdentifier = "LUB-2025-001";
                :>> expiryDate = "2026-12-31";
            }
        }

        part pump : PrecisionPump {
            :>> maxFlowRate = 20.0;
            :>> currentFlowRate = 0.0;
            :>> pumpSpeed = 0.0;
            :>> isRunning = false;
        }

        part controller : ElectronicFlowController {
            :>> targetFlowRate = 5.0;
            :>> tolerance = 0.5;
            :>> dispenseMode = operatorControlled;
            :>> isProgramActive = false;
        }

        part temperatureModule : TemperatureModule {
            :>> targetTemperature = 310.15;
            :>> currentTemperature = 293.15;
            :>> heaterPower = 0.0;
            :>> maxPower = 50.0;
            :>> isActive = false;
        }

        part viscositySensor : ViscositySensor {
            :>> measuredViscosity = 2.0;
            :>> samplingRate = 10.0;
            :>> minViscosity = 0.5;
            :>> maxViscosity = 5.0;
        }

        part frictionSensor : FrictionSensor {
            :>> measuredFriction = 0.5;
            :>> baselineFriction = 0.5;
            :>> currentFriction = 0.5;
            :>> maxAllowedFriction = 0.1;
        }

        part nozzle : ApplicationNozzle {
            :>> tipDiameter = 2.0;
            :>> taperAngle = 30.0;
            :>> isSterile = true;
            :>> flowResistance = 5000.0;
        }

        part ui : UserInterface {
            :>> currentMode = operatorControlled;
            :>> targetFlowRate = 5.0;
            :>> displayStatus = "Standby";
            :>> alertLevel = nominal;
        }

        part powerSupply : PowerSupply {
            :>> outputPower = 0.0;
            :>> maxPower = 100.0;
            :>> isOn = false;
        }

        // Fluid connections
        connection fluidPath1 connect cartridge.fluidOut to pump.fluidIn;
        connection fluidPath2 connect pump.fluidOut to nozzle.fluidIn;

        // Control connections
        connection uiToController connect ui.control to controller.uiControl;
        connection controllerToPump connect controller.pumpControl to pump.controlSignal;

        // Monitoring connections
        connection viscosityToController connect viscositySensor.monitoring to controller.monitoring;
        connection temperatureToController connect temperatureModule.monitoring to controller.monitoring;
        connection frictionToUI connect frictionSensor.monitoring to ui.monitoring;

        // Power connections
        connection powerToPump connect powerSupply.powerOut to pump.powerIn;

        // State Machine
        state machine OperationStateMachine {

            state Idle {
                entry { isOperating = false; }
            }

            state Priming {
                entry { isPrimed = false; }
                do prime;
                exit { isPrimed = true; }
            }

            state Ready {
                entry { isOperating = true; }
            }

            state Dispensing {
                do dispense;
            }

            state Monitoring {
                do monitorLubricant;
            }

            state Error {
                entry { isOperating = false; }
                do shutdown;
            }

            transition from Idle to Priming
                when systemActivated == true;

            transition from Priming to Ready
                when primingComplete == true;

            transition from Priming to Error
                when primingFailure == true;

            transition from Ready to Dispensing
                when dispenseCommandReceived == true;

            transition from Dispensing to Monitoring
                when dispensingCycleComplete == true;

            transition from Monitoring to Dispensing
                when continueDispensingFlag == true;

            transition from Monitoring to Ready
                when dispenseStopped == true;

            transition from Monitoring to Error
                when frictionExceedsLimit == true or viscosityOutOfRange == true;

            transition from Error to Idle
                when systemReset == true;
        }

        // Actions
        action initialize {
            doc "Initialize the system for a surgical procedure.";
            out ready : Boolean;
        }

        action prime {
            doc "Prime all fluid lines with lubricant for immediate dispensing.";
            in gel : LubricantGel;
            out primed : Boolean;
        }

        action dispense {
            doc "Dispense lubricant at controlled rate during procedure.";
            in flowRate : FlowRateValue;
            in mode : DispenseMode;
            out dispensedVolume : VolumeValue;
        }

        action monitorLubricant {
            doc "Continuously monitor lubricant viscosity, temperature, and friction.";
            out viscosity : ViscosityValue;
            out temperature : TemperatureValue;
            out friction : FrictionCoefficientValue;
        }

        action evaluateEffectiveness {
            doc "Evaluate friction reduction effectiveness for patient safety.";
            in baseline : FrictionCoefficientValue;
            in measured : FrictionCoefficientValue;
            out reduction : FrictionCoefficientValue;
            out reductionPercentage : PercentageValue;
        }

        action shutdown {
            doc "Safely shut down the system after procedure completion.";
            out completed : Boolean;
        }

        constraint totalDispensedLimit { totalDispensedVolume <= cartridge.fillVolume }
        constraint frictionReductionTarget { currentFriction < baselineFriction }
        constraint viscosityMonitoringRange { currentViscosity >= 0.5 and currentViscosity <= 5.0 }
        constraint temperatureOperatingRange { currentTemperature >= 309.15 and currentTemperature <= 313.15 }
    }

    // ===== System Instance =====

    part surgicalLubricantSystem : SurgicalLubricantSystem {
        :>> systemIdentifier = "SLDS-2025-001";
        :>> procedureType = laparoscopy;
        :>> targetFlowRate = 5.0;
        :>> currentViscosity = 2.0;
        :>> currentTemperature = 310.15;
        :>> currentFriction = 0.5;
        :>> baselineFriction = 0.5;
        :>> frictionReduction = 0.0;
        :>> frictionReductionPercent = 0.0;
        :>> isPrimed = false;
        :>> isOperating = false;
        :>> totalDispensedVolume = 0.0;
        :>> systemActivated = false;
        :>> primingComplete = false;
        :>> primingFailure = false;
        :>> dispenseCommandReceived = false;
        :>> dispensingCycleComplete = false;
        :>> continueDispensingFlag = false;
        :>> dispenseStopped = false;
        :>> frictionExceedsLimit = false;
        :>> viscosityOutOfRange = false;
        :>> systemReset = false;
    }

    // ===== Requirements =====

    requirement def SterilityRequirement {
        doc "The lubricant and delivery system must maintain sterility throughout use in the operating room.";
        ref subject : LubricantGel;
        constraint { subject.isSterile == true }
    }

    requirement def BiocompatibilityRequirement {
        doc "The lubricant must be biocompatible for safe contact with patient tissues.";
        ref subject : LubricantGel;
        constraint { subject.isBiocompatible == true }
    }

    requirement def WaterSolubilityRequirement {
        doc "The lubricant must be water-soluble for easy cleaning after the surgery is complete.";
        ref subject : LubricantGel;
        constraint { subject.isWaterSoluble == true }
    }

    requirement def ViscosityAtBodyTempRequirement {
        doc "Lubricant viscosity must be in the optimal range at body temperature (approximately 37 degrees Celsius).";
        ref subject : LubricantGel;
        attribute minViscosity : ViscosityValue;
        attribute maxViscosity : ViscosityValue;
        attribute minTemperature : TemperatureValue;
        attribute maxTemperature : TemperatureValue;
        constraint {
            subject.viscosity >= minViscosity and
            subject.viscosity <= maxViscosity
        }
        constraint {
            subject.temperature >= minTemperature and
            subject.temperature <= maxTemperature
        }
    }

    requirement def FlowRatePrecisionRequirement {
        doc "The system must dispense lubricant at a precise and stable rate as commanded by the operator or pre-set program.";
        ref subject : SurgicalLubricantSystem;
        attribute targetFlow : FlowRateValue;
        attribute tolerance : FlowRateValue;
        constraint {
            subject.pump.currentFlowRate >= targetFlow - tolerance and
            subject.pump.currentFlowRate <= targetFlow + tolerance
        }
    }

    requirement def FrictionReductionRequirement {
        doc "The system must achieve a minimum friction reduction to minimize trauma to patient tissues and ensure smooth instrument manipulation.";
        ref subject : SurgicalLubricantSystem;
        attribute maxResidualFriction : FrictionCoefficientValue;
        attribute minReductionPercentage : PercentageValue;
        constraint {
            subject.currentFriction <= maxResidualFriction
        }
        constraint {
            subject.baselineFriction > 0 and
            ((subject.baselineFriction - subject.currentFriction) / subject.baselineFriction) * 100.0 >= minReductionPercentage
        }
    }

    requirement def PrimingRequirement {
        doc "The system must perform a priming action before dispensing to ensure all lines are full and ready for immediate use.";
        ref subject : SurgicalLubricantSystem;
        constraint { subject.isPrimed == true }
    }

    requirement def DispenseAccuracyRequirement {
        doc "The total dispensed volume must match the commanded volume within an acceptable tolerance.";
        ref subject : SurgicalLubricantSystem;
        attribute commandedVolume : VolumeValue;
        attribute actualVolume : VolumeValue;
        attribute volumeTolerance : VolumeValue;
        constraint {
            actualVolume >= commandedVolume - volumeTolerance and
            actualVolume <= commandedVolume + volumeTolerance
        }
    }

    requirement def TemperatureControlRequirement {
        doc "The system must adjust and maintain lubricant temperature within the body temperature range for optimal performance.";
        ref subject : SurgicalLubricantSystem;
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        constraint {
            subject.currentTemperature >= minTemp and
            subject.currentTemperature <= maxTemp
        }
    }

    requirement def ViscosityMonitoringRequirement {
        doc "The system must continuously monitor lubricant viscosity and alert if it falls outside the acceptable range.";
        ref subject : SurgicalLubricantSystem;
        attribute minViscosity : ViscosityValue;
        attribute maxViscosity : ViscosityValue;
        constraint {
            subject.currentViscosity >= minViscosity and
            subject.currentViscosity <= maxViscosity
        }
    }

    requirement def CartridgeCapacityRequirement {
        doc "The disposable cartridge must contain sufficient lubricant for the duration of a surgical procedure.";
        ref subject : LubricantCartridge;
        attribute minFillVolume : VolumeValue;
        constraint { subject.fillVolume >= minFillVolume }
    }

    requirement def NozzlePrecisionRequirement {
        doc "The application nozzle must have a tapered tip suitable for accurate delivery to instruments and tissue surfaces.";
        ref subject : ApplicationNozzle;
        attribute maxTipDiameter : DiameterValue;
        attribute minTipDiameter : DiameterValue;
        constraint {
            subject.tipDiameter >= minTipDiameter and
            subject.tipDiameter <= maxTipDiameter
        }
    }

    requirement def ContinuousEffectivenessEvaluation {
        doc "The system must continuously evaluate its effectiveness by measuring the reduction in surface friction during the procedure.";
        ref subject : SurgicalLubricantSystem;
        constraint {
            subject.currentFriction < subject.baselineFriction
        }
    }

    requirement def CartridgeDisposableRequirement {
        doc "The lubricant cartridge must be disposable and pre-filled to ensure sterility and ease of use.";
        ref subject : LubricantCartridge;
        constraint { subject.isDisposable == true }
        constraint { subject.isPreFilled == true }
    }

    // ===== Requirement Usages =====

    requirement sterilityReq : SterilityRequirement {
        :>> subject = surgicalLubricantSystem.cartridge.containedGel;
    }

    requirement biocompatReq : BiocompatibilityRequirement {
        :>> subject = surgicalLubricantSystem.cartridge.containedGel;
    }

    requirement waterSolReq : WaterSolubilityRequirement {
        :>> subject = surgicalLubricantSystem.cartridge.containedGel;
    }

    requirement viscosityReq : ViscosityAtBodyTempRequirement {
        :>> minViscosity = 0.5;
        :>> maxViscosity = 5.0;
        :>> minTemperature = 309.15;
        :>> maxTemperature = 313.15;
    }

    requirement flowPrecisionReq : FlowRatePrecisionRequirement {
        :>> targetFlow = 5.0;
        :>> tolerance = 0.5;
    }

    requirement frictionReductionReq : FrictionReductionRequirement {
        :>> maxResidualFriction = 0.1;
        :>> minReductionPercentage = 80.0;
    }

    requirement primingReq : PrimingRequirement;

    requirement dispenseAccReq : DispenseAccuracyRequirement {
        :>> volumeTolerance = 2.0;
    }

    requirement tempCtrlReq : TemperatureControlRequirement {
        :>> minTemp = 309.15;
        :>> maxTemp = 313.15;
    }

    requirement viscosityMonitorReq : ViscosityMonitoringRequirement {
        :>> minViscosity = 0.5;
        :>> maxViscosity = 5.0;
    }

    requirement cartridgeCapReq : CartridgeCapacityRequirement {
        :>> minFillVolume = 100.0;
    }

    requirement nozzlePrecisionReq : NozzlePrecisionRequirement {
        :>> minTipDiameter = 0.5;
        :>> maxTipDiameter = 5.0;
    }

    requirement continuousEvalReq : ContinuousEffectivenessEvaluation;

    requirement cartridgeDispReq : CartridgeDisposableRequirement;

    // ===== Verifications =====

    verification FrictionReductionVerification {
        doc "Verify that friction reduction meets the specified requirement through bench testing with simulated tissue surfaces.";
        subject requirement = frictionReductionReq;
        objective "Measure residual friction after lubricant application and confirm it is below 0.1 with at least 80 percent reduction.";
    }

    verification ViscosityVerification {
        doc "Verify that lubricant viscosity is within the acceptable range at body temperature.";
        subject requirement = viscosityReq;
        objective "Measure viscosity at 310.15 K and confirm it is between 0.5 and 5.0 Pa·s.";
    }

    verification FlowRateVerification {
        doc "Verify that the system dispenses lubricant at the precise and stable flow rate.";
        subject requirement = flowPrecisionReq;
        objective "Measure actual flow rate over a 60-second dispensing period and confirm it is within 0.5 mL/min of the target rate.";
    }

    verification SterilityVerification {
        doc "Verify that the lubricant maintains sterility from manufacturing through end of procedure.";
        subject requirement = sterilityReq;
        objective "Conduct sterility testing on sealed cartridge samples and post-dispense samples per ISO 11607.";
    }

    verification TemperatureVerification {
        doc "Verify that the temperature control module maintains lubricant within body temperature range.";
        subject requirement = tempCtrlReq;
        objective "Monitor lubricant temperature over a 30-minute operation and confirm it remains between 309.15 K and 313.15 K.";
    }

    verification PrimingVerification {
        doc "Verify that the priming action fills all lines and prepares the system for immediate dispensing.";
        subject requirement = primingReq;
        objective "Execute priming sequence and confirm lubricant arrives at nozzle tip within 5 seconds.";
    }

    verification DispenseAccuracyVerification {
        doc "Verify that the dispensed volume matches the commanded volume.";
        subject requirement = dispenseAccReq;
        objective "Command 10 mL dispense and measure actual output, confirming it is within 2 mL tolerance.";
    }

    verification NozzlePrecisionVerification {
        doc "Verify that the nozzle tip geometry allows accurate delivery to target areas.";
        subject requirement = nozzlePrecisionReq;
        objective "Inspect nozzle tip diameter and confirm it is between 0.5 mm and 5.0 mm.";
    }

    verification ContinuousEvalVerification {
        doc "Verify that the system continuously evaluates friction reduction during operation.";
        subject requirement = continuousEvalReq;
        objective "Monitor friction sensor output during dispensing and confirm it tracks below baseline.";
    }
}
