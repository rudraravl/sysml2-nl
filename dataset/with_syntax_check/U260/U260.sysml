package InjectorPenSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import SequenceFunctions::*;
    
    attribute def DoseAmount :> Real;
    
    item def Medication {
        attribute concentration: Real;
        attribute viscosity: Real;
    }
    
    port def MedicationFlowPort {
        out item medication: Medication;
    }
    
    port def DoseControlPort {
        in attribute doseCommand: DoseAmount;
        out attribute doseConfirmation: DoseAmount;
    }
    
    port def PressureMonitorPort {
        out attribute pressure: PressureValue;
        out attribute forceApplied: ForceValue;
    }
    
    port def SafetyInterlockPort {
        in attribute safetyEnabled: Boolean;
        out attribute safetyStatus: Boolean;
    }
    
    part def CartridgeAssembly {
        attribute capacity: VolumeValue;
        attribute currentVolume: VolumeValue;
        attribute reservoirPressure: PressureValue;
        port medicationOut: MedicationFlowPort;
        port pressureMonitor: PressureMonitorPort;
        
        assert constraint volumeConstraint {
            currentVolume >= 0.0 and currentVolume <= capacity
        }
        
        assert constraint pressureLimit {
            reservoirPressure <= 600000.0
        }
    }
    
    part def DoseSelectionMechanism {
        attribute selectedDose: DoseAmount;
        attribute minDose: DoseAmount;
        attribute maxDose: DoseAmount;
        attribute doseIncrement: DoseAmount;
        attribute dialPosition: Real;
        port doseControl: DoseControlPort;
        
        assert constraint doseRange {
            selectedDose >= minDose and selectedDose <= maxDose
        }
    }
    
    part def NeedleAssembly {
        attribute needleLength: LengthValue;
        attribute needleGauge: Real;
        attribute boreDiameter: LengthValue;
        attribute isAttached: Boolean;
        attribute isCapped: Boolean;
        port medicationIn: MedicationFlowPort;
        
        assert constraint needleAttached {
            not isCapped implies isAttached
        }
    }
    
    part def PlungerDriveMechanism {
        attribute position: LengthValue;
        attribute maxTravel: LengthValue;
        attribute appliedForce: ForceValue;
        attribute maxForce: ForceValue;
        attribute isEngaged: Boolean;
        attribute velocity: VelocityValue;
        port pressureOut: PressureMonitorPort;
        
        assert constraint forceLimit {
            appliedForce <= maxForce
        }
        
        assert constraint travelLimit {
            position >= 0.0 and position <= maxTravel
        }
    }
    
    part def SafetyLockMechanism {
        attribute isLocked: Boolean;
        attribute needleShieldDeployed: Boolean;
        attribute capAttached: Boolean;
        attribute injectionButtonBlocked: Boolean;
        port safetyInterlock: SafetyInterlockPort;
        
        assert constraint safetyLogic {
            (capAttached or needleShieldDeployed) implies isLocked
        }
    }
    
    part def DisplayAndIndicator {
        attribute doseDisplay: DoseAmount;
        attribute batteryLevel: Real;
        attribute errorCode: Integer;
        attribute ledStatus: Boolean;
    }
    
    part def InjectorPen {
        part cartridge: CartridgeAssembly {
            attribute :>> capacity = 3.0e-6;
            attribute :>> currentVolume = 3.0e-6;
            attribute :>> reservoirPressure = 100000.0;
        }
        
        part doseSelector: DoseSelectionMechanism {
            attribute :>> minDose = 0.5;
            attribute :>> maxDose = 80.0;
            attribute :>> doseIncrement = 0.5;
            attribute :>> selectedDose = 0.0;
            attribute :>> dialPosition = 0.0;
        }
        
        part needle: NeedleAssembly {
            attribute :>> needleLength = 0.008;
            attribute :>> needleGauge = 31.0;
            attribute :>> boreDiameter = 0.00025;
            attribute :>> isAttached = false;
            attribute :>> isCapped = true;
        }
        
        part plungerDrive: PlungerDriveMechanism {
            attribute :>> maxTravel = 0.012;
            attribute :>> maxForce = 30.0;
            attribute :>> position = 0.0;
            attribute :>> appliedForce = 0.0;
            attribute :>> isEngaged = false;
        }
        
        part safetyLock: SafetyLockMechanism {
            attribute :>> isLocked = true;
            attribute :>> needleShieldDeployed = true;
            attribute :>> capAttached = true;
            attribute :>> injectionButtonBlocked = true;
        }
        
        part display: DisplayAndIndicator {
            attribute :>> doseDisplay = 0.0;
            attribute :>> batteryLevel = 100.0;
            attribute :>> errorCode = 0;
            attribute :>> ledStatus = false;
        }
        
        connection medicationPath connect 
            cartridge.medicationOut to needle.medicationIn;
        
        connection pressureFeedback connect
            plungerDrive.pressureOut to cartridge.pressureMonitor;
        
        connection safetyControl connect
            safetyLock.safetyInterlock to doseSelector.doseControl;
        
        perform action operateInjectorPen;
    }
    
    action def AttachNeedle {
        in pen: InjectorPen;
        out needleSecured: Boolean;
    }
    
    action def RemoveCap {
        in needle: NeedleAssembly;
        out capRemoved: Boolean;
    }
    
    action def SelectDose {
        in requestedDose: DoseAmount;
        in mechanism: DoseSelectionMechanism;
        out configuredDose: DoseAmount;
        out dialSet: Boolean;
    }
    
    action def PrimeDevice {
        in cartridge: CartridgeAssembly;
        in needle: NeedleAssembly;
        in primeVolume: VolumeValue;
        out airRemoved: Boolean;
        out remainingVolume: VolumeValue;
    }
    
    action def PerformInjection {
        in targetDepth: LengthValue;
        in targetPressure: PressureValue;
        in doseAmount: DoseAmount;
        in plunger: PlungerDriveMechanism;
        in cartridge: CartridgeAssembly;
        out deliveredVolume: VolumeValue;
        out injectionComplete: Boolean;
        out finalPressure: PressureValue;
    }
    
    action def WithdrawNeedle {
        in needle: NeedleAssembly;
        in safetyLock: SafetyLockMechanism;
        out needleWithdrawn: Boolean;
        out shieldDeployed: Boolean;
    }
    
    action def DisposeNeedle {
        in needle: NeedleAssembly;
        out needleRemoved: Boolean;
        out penSafe: Boolean;
    }
    
    action operateInjectorPen {
        first start;
        
        then action attachNeedle: AttachNeedle {
            in pen = InjectorPen;
            out needleSecured;
        }
        
        then decide;
            if attachNeedle.needleSecured then removeCap;
            if not attachNeedle.needleSecured then abortOperation;
        
        action removeCap: RemoveCap {
            out capRemoved;
        }
        
        then action selectDose: SelectDose {
            out configuredDose;
            out dialSet;
        }
        
        then decide;
            if selectDose.dialSet and selectDose.configuredDose > 0.0 then primeDevice;
            if not selectDose.dialSet or selectDose.configuredDose <= 0.0 then abortOperation;
        
        action primeDevice: PrimeDevice {
            in primeVolume = 1.0e-7;
            out airRemoved;
            out remainingVolume;
        }
        
        then decide;
            if primeDevice.airRemoved then performInjection;
            if not primeDevice.airRemoved then abortOperation;
        
        action performInjection: PerformInjection {
            in targetDepth = 0.008;
            in targetPressure = 250000.0;
            out deliveredVolume;
            out injectionComplete;
            out finalPressure;
        }
        
        then action withdrawNeedle: WithdrawNeedle {
            out needleWithdrawn;
            out shieldDeployed;
        }
        
        then action disposeNeedle: DisposeNeedle {
            out needleRemoved;
            out penSafe;
        }
        
        then done;
        
        action abortOperation {
            then done;
        }
    }
    
    requirement <'INJ-REQ-001'> primaryFunctionRequirement {
        doc /* 
            The injector pen system shall deliver a precise, user-selected dose 
            of medication subcutaneously through a controlled injection mechanism 
            with integrated safety features to prevent accidental needle exposure 
            and ensure accurate dosing.
        */
        
        subject injectorPen: InjectorPen;
    }
    
    requirement <'INJ-REQ-002'> safetyRequirement {
        doc /* 
            The injector pen shall incorporate multiple safety mechanisms to prevent 
            accidental needle stick injuries and ensure safe operation.
        */
        
        subject safetySystem: SafetyLockMechanism;
    }
    
    requirement <'INJ-REQ-003'> usabilityRequirement {
        doc /* 
            The injector pen shall enable intuitive single-handed operation 
            with clear dose indication and feedback.
        */
        
        subject pen: InjectorPen;
    }
    
    requirement <'INJ-REQ-004'> performanceRequirement {
        doc /* 
            The injector pen shall maintain consistent performance across 
            its operational range and medication capacity.
        */
        
        subject cart: CartridgeAssembly;
    }
    
    requirement <'INJ-REQ-005'> mechanicalRequirement {
        doc /* 
            The plunger drive mechanism shall deliver consistent force 
            throughout the injection cycle.
        */
        
        subject drive: PlungerDriveMechanism;
    }
    
    requirement systemRequirements {
        doc /* 
            Top-level system requirements for the injector pen encompassing 
            primary function, safety, usability, performance, and mechanical design.
        */
        
        require primaryFunctionRequirement;
        require safetyRequirement;
        require usabilityRequirement;
        require performanceRequirement;
        require mechanicalRequirement;
    }
}
