package InjectorPenSystem {

    import ScalarValues::*;

    // ============ Units ============
    unit def Newton;
    unit def MilliLiter;
    unit def InsulinUnit;
    unit def Percent;
    unit def Bar;
    unit def MilliMeter;
    unit def Degree;

    // ============ Value Types ============
    attribute def ForceValue :> Real { unit Newton; }
    attribute def VolumeValue :> Real { unit MilliLiter; }
    attribute def DoseValue :> Real { unit InsulinUnit; }
    attribute def BatteryLevelValue :> Real { unit Percent; }
    attribute def PressureValue :> Real { unit Bar; }
    attribute def LengthValue :> Real { unit MilliMeter; }
    attribute def AngleValue :> Real { unit Degree; }

    // ============ Items ============
    item def Medication {
        attribute concentration: Real;
        attribute volume: VolumeValue;
    }
    item def AirBubble {
        attribute volume: VolumeValue;
    }
    item def MedicationDose {
        attribute amount: DoseValue;
    }

    // ============ Ports ============
    port def FluidPort {
        out item medication: Medication;
        out item air: AirBubble;
    }
    port def MechanicalPort {
        attribute force: ForceValue;
    }
    port def ElectricalPowerPort {
        attribute voltage: Real;
        attribute current: Real;
    }
    port def SignalPort {
        attribute value: Real;
    }
    port def UserInteractionPort {
        in attribute doseSetting: DoseValue;
        in attribute activationRequest: Boolean;
        out attribute displayedDose: DoseValue;
        out attribute batteryLevel: BatteryLevelValue;
        out attribute statusMessage: String;
    }

    // ============ Interfaces ============
    interface def FluidConnection {
        end supplier: FluidPort;
        end consumer: FluidPort;
    }
    interface def MechanicalConnection {
        end supplier: MechanicalPort;
        end consumer: MechanicalPort;
    }
    interface def PowerConnection {
        end supplier: ElectricalPowerPort;
        end consumer: ElectricalPowerPort;
    }
    interface def SignalConnection {
        end supplier: SignalPort;
        end consumer: SignalPort;
    }

    // ============ Part Definitions ============

    part def MedicationCartridge {
        attribute capacity: VolumeValue = 3.0 [MilliLiter];
        attribute remainingVolume: VolumeValue = 3.0 [MilliLiter];
        attribute isInstalled: Boolean = false;
        item storedMedication: Medication;
        port fluidOut: FluidPort;
        action def dispense(amount: VolumeValue) {
            remainingVolume = remainingVolume - amount;
        }
    }

    part def Needle {
        attribute length: LengthValue = 8.0 [MilliMeter];
        attribute gauge: Real = 31.0;
        attribute isSterile: Boolean = true;
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
        flow medication through fluidIn to fluidOut;
    }

    part def NeedleCap {
        attribute isAttached: Boolean = true;
        action def remove { isAttached = false; }
        action def attach { isAttached = true; }
    }

    part def NeedleShield {
        attribute isDeployed: Boolean = false;
        attribute deploymentPosition: LengthValue = 0.0 [MilliMeter];
        port actuationPort: MechanicalPort;
        action def deploy {
            isDeployed = true;
            deploymentPosition = 12.0 [MilliMeter];
        }
        action def retract {
            isDeployed = false;
            deploymentPosition = 0.0 [MilliMeter];
        }
    }

    part def NeedleAssembly {
        part needle: Needle;
        part cap: NeedleCap;
        part shield: NeedleShield;
        port fluidIn: FluidPort;
        port fluidOut: FluidPort;
        port shieldActuation: MechanicalPort;
        connection needleFluidIn: FluidConnection connect fluidIn to needle.fluidIn;
        connection needleFluidOut: FluidConnection connect needle.fluidOut to fluidOut;
        connection shieldLink: MechanicalConnection connect shieldActuation to shield.actuationPort;
    }

    part def DoseSelectionDial {
        attribute selectedDose: DoseValue = 0.0 [InsulinUnit];
        attribute minDose: DoseValue = 1.0 [InsulinUnit];
        attribute maxDose: DoseValue = 60.0 [InsulinUnit];
        attribute dialAngle: AngleValue = 0.0 [Degree];
        port doseSignal: SignalPort;
        action def selectDose(in requestedDose: DoseValue) {
            if requestedDose >= minDose && requestedDose <= maxDose {
                selectedDose = requestedDose;
                dialAngle = requestedDose * 6.0 [Degree];
                doseSignal.value = requestedDose;
            }
        }
        action def resetDose {
            selectedDose = 0.0 [InsulinUnit];
            dialAngle = 0.0 [Degree];
            doseSignal.value = 0.0;
        }
    }

    part def Display {
        attribute displayedDose: DoseValue = 0.0 [InsulinUnit];
        attribute batteryLevel: BatteryLevelValue = 100.0 [Percent];
        attribute statusMessage: String = "Ready";
        port displayInput: SignalPort;
        action def updateDisplay(in dose: DoseValue, in battery: BatteryLevelValue, in status: String) {
            displayedDose = dose;
            batteryLevel = battery;
            statusMessage = status;
        }
        action def showError(in message: String) {
            statusMessage = message;
        }
    }

    part def Battery {
        attribute chargeLevel: BatteryLevelValue = 100.0 [Percent];
        attribute nominalVoltage: Real = 3.0;
        attribute isLow: Boolean = false;
        port powerOut: ElectricalPowerPort;
        action def discharge(amount: Real) {
            chargeLevel = chargeLevel - amount;
            if chargeLevel < 20.0 [Percent] { isLow = true; }
        }
        action def checkLevel: BatteryLevelValue { return chargeLevel; }
    }

    part def PressureSensor {
        attribute measuredPressure: PressureValue = 0.0 [Bar];
        attribute threshold: PressureValue = 2.5 [Bar];
        port pressureSignal: SignalPort;
        port sensingPort: MechanicalPort;
        action def measurePressure: PressureValue {
            measuredPressure = sensingPort.force * 0.01 [Bar];
            pressureSignal.value = measuredPressure;
            return measuredPressure;
        }
        action def isOverPressure: Boolean {
            return measuredPressure > threshold;
        }
    }

    part def ForceSensor {
        attribute measuredForce: ForceValue = 0.0 [Newton];
        attribute targetForce: ForceValue = 15.0 [Newton];
        port forceSignal: SignalPort;
        port sensingPort: MechanicalPort;
        action def measureForce: ForceValue {
            measuredForce = sensingPort.force;
            forceSignal.value = measuredForce;
            return measuredForce;
        }
        action def isForceAdequate: Boolean {
            return measuredForce >= targetForce;
        }
    }

    part def Plunger {
        attribute position: LengthValue = 0.0 [MilliMeter];
        attribute maxStroke: LengthValue = 50.0 [MilliMeter];
        port driveInterface: MechanicalPort;
        port fluidInterface: FluidPort;
        action def advance(distance: LengthValue) {
            position = position + distance;
        }
        action def reset {
            position = 0.0 [MilliMeter];
        }
    }

    part def PlungerDriveMechanism {
        attribute appliedForce: ForceValue = 0.0 [Newton];
        attribute targetForce: ForceValue = 15.0 [Newton];
        attribute driveSpeed: Real = 1.0;
        attribute isActuating: Boolean = false;
        port driveOutput: MechanicalPort;
        port controlInput: SignalPort;
        port powerInput: ElectricalPowerPort;
        part motor {
            attribute speed: Real;
        }
        part gearTrain {
            attribute ratio: Real = 10.0;
        }
        action def applyForce(target: ForceValue) {
            targetForce = target;
            appliedForce = target;
            driveOutput.force = appliedForce;
            isActuating = true;
        }
        action def stopDrive {
            appliedForce = 0.0 [Newton];
            driveOutput.force = 0.0 [Newton];
            isActuating = false;
        }
        action def retract {
            appliedForce = 0.0 [Newton];
            driveOutput.force = 0.0 [Newton];
            isActuating = false;
        }
    }

    part def ActivationButton {
        attribute isPressed: Boolean = false;
        attribute isLocked: Boolean = true;
        port buttonSignal: SignalPort;
        action def press {
            if !isLocked {
                isPressed = true;
                buttonSignal.value = 1.0;
            }
        }
        action def release {
            isPressed = false;
            buttonSignal.value = 0.0;
        }
        action def lock { isLocked = true; }
        action def unlock { isLocked = false; }
    }

    part def SafetyLockMechanism {
        attribute isLocked: Boolean = true;
        attribute capDetected: Boolean = true;
        attribute injectionComplete: Boolean = false;
        attribute shieldDeployed: Boolean = false;
        port lockControl: SignalPort;
        port shieldActuation: MechanicalPort;
        action def evaluateLock {
            if capDetected {
                isLocked = true;
            } else if injectionComplete {
                isLocked = true;
            } else {
                isLocked = false;
            }
        }
        action def deployShield {
            shieldActuation.force = 5.0 [Newton];
            shieldDeployed = true;
        }
        action def reset {
            isLocked = true;
            injectionComplete = false;
            shieldDeployed = false;
        }
    }

    part def PenBody {
        attribute serialNumber: String = "INJ-00001";
        attribute model: String = "ElectroPen-100";
        part cartridgeBay {
            attribute isOccupied: Boolean = false;
        }
        part needleAttachment {
            attribute isAttached: Boolean = false;
        }
    }

    // ============ Controller and State Machine ============

    part def InjectorPenController {
        attribute currentDose: DoseValue = 0.0 [InsulinUnit];
        attribute batteryLevel: BatteryLevelValue = 100.0 [Percent];
        attribute systemStatus: String = "Idle";
        attribute capOn: Boolean = true;
        attribute needleAttached: Boolean = false;
        attribute primed: Boolean = false;
        attribute injectionComplete: Boolean = false;
        attribute doseDelivered: DoseValue = 0.0 [InsulinUnit];

        port doseInput: SignalPort;
        port buttonInput: SignalPort;
        port pressureInput: SignalPort;
        port forceInput: SignalPort;
        port displayOutput: SignalPort;
        port lockOutput: SignalPort;
        port powerInput: ElectricalPowerPort;

        state injectionProcess: InjectionProcess;

        action def primePen {
            systemStatus = "Priming";
            // Drive plunger forward to expel air bubbles
            primed = true;
            systemStatus = "Ready";
        }

        action def performInjection(dose: DoseValue) {
            systemStatus = "Injecting";
            doseDelivered = dose;
            injectionComplete = true;
            systemStatus = "InjectionComplete";
        }

        action def withdrawPen {
            systemStatus = "ShieldDeploying";
            // Trigger safety shield deployment
            systemStatus = "Safe";
        }
    }

    state def InjectionProcess {
        entry; then Idle;
        state Idle;
        state NeedleAttached;
        state DoseSelected;
        state Priming;
        state Ready;
        state Injecting;
        state InjectionComplete;
        state ShieldDeployed;

        transition Idle -> NeedleAttached when needleAttached;
        transition NeedleAttached -> DoseSelected when currentDose > 0.0 [InsulinUnit];
        transition DoseSelected -> Priming when buttonInput.value > 0.0;
        transition Priming -> Ready when primed;
        transition Ready -> Injecting when buttonInput.value > 0.0;
        transition Injecting -> InjectionComplete when injectionComplete;
        transition InjectionComplete -> ShieldDeployed when !capOn;
        transition ShieldDeployed -> Idle when !needleAttached;
    }

    // ============ Top-level Injector Pen ============

    part def InjectorPen {
        part body: PenBody;
        part cartridge: MedicationCartridge;
        part needleAssembly: NeedleAssembly;
        part doseDial: DoseSelectionDial;
        part display: Display;
        part drive: PlungerDriveMechanism;
        part plunger: Plunger;
        part safetyLock: SafetyLockMechanism;
        part activationButton: ActivationButton;
        part battery: Battery;
        part pressureSensor: PressureSensor;
        part forceSensor: ForceSensor;
        part controller: InjectorPenController;

        port userInterface: UserInteractionPort;

        // Fluid path: cartridge -> needle
        connection cartridgeToNeedle: FluidConnection connect cartridge.fluidOut to needleAssembly.fluidIn;
        // Plunger acts on cartridge fluid
        connection plungerToCartridge: FluidConnection connect plunger.fluidInterface to cartridge.fluidOut;
        // Drive mechanism applies force to plunger
        connection driveToPlunger: MechanicalConnection connect drive.driveOutput to plunger.driveInterface;
        // Plunger force sensed
        connection plungerToForceSensor: MechanicalConnection connect plunger.driveInterface to forceSensor.sensingPort;
        // Pressure sensed at cartridge output
        connection cartridgeToPressureSensor: MechanicalConnection connect drive.driveOutput to pressureSensor.sensingPort;
        // Power distribution
        connection batteryToDrive: PowerConnection connect battery.powerOut to drive.powerInput;
        connection batteryToController: PowerConnection connect battery.powerOut to controller.powerInput;
        // Signal routing
        connection doseSignal: SignalConnection connect doseDial.doseSignal to controller.doseInput;
        connection buttonSignal: SignalConnection connect activationButton.buttonSignal to controller.buttonInput;
        connection pressureSignal: SignalConnection connect pressureSensor.pressureSignal to controller.pressureInput;
        connection forceSignal: SignalConnection connect forceSensor.forceSignal to controller.forceInput;
        connection displaySignal: SignalConnection connect controller.displayOutput to display.displayInput;
        connection lockSignal: SignalConnection connect controller.lockOutput to safetyLock.lockControl;
        // Shield actuation
        connection shieldActuationLink: MechanicalConnection connect safetyLock.shieldActuation to needleAssembly.shieldActuation;

        flow medication from cartridge.fluidOut to needleAssembly.fluidIn;
        flow medication from needleAssembly.fluidOut to userInterface;
    }

    // ============ Requirements ============

    requirement def DoseAccuracyRequirement {
        doc "The injector pen shall deliver the selected dose within +/- 5% accuracy."
        subject pen: InjectorPen;
        attribute requiredAccuracy: Real = 0.05;
        attribute maxDose: DoseValue = 60.0 [InsulinUnit];
        require pen.controller.doseDelivered <= pen.controller.currentDose * (1.0 + requiredAccuracy);
        require pen.controller.doseDelivered >= pen.controller.currentDose * (1.0 - requiredAccuracy);
    }

    requirement def SafetyLockRequirement {
        doc "The activation button shall be locked when the needle cap is attached or when the pen is not ready for use."
        subject pen: InjectorPen;
        require pen.safetyLock.capDetected implies pen.activationButton.isLocked;
        require !pen.controller.primed implies pen.activationButton.isLocked;
    }

    requirement def NeedleShieldRequirement {
        doc "After injection is complete and the pen is withdrawn, a needle shield shall deploy to prevent accidental needle-stick injuries."
        subject pen: InjectorPen;
        require pen.controller.injectionComplete && !pen.safetyLock.capDetected implies pen.needleAssembly.shield.isDeployed;
    }

    requirement def BatteryLifeRequirement {
        doc "The injector pen shall operate for at least 30 days on a single charge under normal use."
        subject pen: InjectorPen;
        attribute minDays: Integer = 30;
        require pen.battery.chargeLevel >= 10.0 [Percent];
    }

    requirement def DisplayRequirement {
        doc "The display shall show the selected dose, remaining battery level, and any system errors."
        subject pen: InjectorPen;
        require pen.display.displayedDose == pen.controller.currentDose;
        require pen.display.batteryLevel == pen.battery.chargeLevel;
    }

    requirement def PrimingRequirement {
        doc "The pen shall be primed to clear air bubbles before injection can be performed."
        subject pen: InjectorPen;
        require !pen.controller.primed implies pen.activationButton.isLocked;
    }

    requirement def CartridgeReplaceabilityRequirement {
        doc "The injector pen shall accept replaceable medication cartridges with a capacity of up to 3.0 mL."
        subject pen: InjectorPen;
        attribute maxCapacity: VolumeValue = 3.0 [MilliLiter];
        require pen.cartridge.capacity <= maxCapacity;
    }

    requirement def OperationalSequenceRequirement {
        doc "The injector pen shall follow the operational sequence: attach needle, select dose, prime, inject, withdraw."
        subject pen: InjectorPen;
        require pen.controller.injectionProcess.InjectionProcess.needleAttached before pen.controller.injectionProcess.InjectionProcess.DoseSelected;
        require pen.controller.injectionProcess.InjectionProcess.DoseSelected before pen.controller.injectionProcess.InjectionProcess.Priming;
        require pen.controller.injectionProcess.InjectionProcess.Priming before pen.controller.injectionProcess.InjectionProcess.Injecting;
        require pen.controller.injectionProcess.InjectionProcess.Injecting before pen.controller.injectionProcess.InjectionProcess.ShieldDeployed;
    }

    // ============ Requirement Verification ============

    verification def DoseAccuracyVerification {
        subject pen: InjectorPen;
        objective {
            verify DoseAccuracyRequirement for pen;
        }
    }

    verification def SafetyLockVerification {
        subject pen: InjectorPen;
        objective {
            verify SafetyLockRequirement for pen;
        }
    }

    verification def NeedleShieldVerification {
        subject pen: InjectorPen;
        objective {
            verify NeedleShieldRequirement for pen;
        }
    }

}
