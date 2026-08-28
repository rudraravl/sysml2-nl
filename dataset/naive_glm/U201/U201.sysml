package DiathermyTherapySystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    package Units {
        value def PowerLevel :> Real { unit 'W'; }
        value def Temperature :> Real { unit 'Celsius'; }
        value def Duration :> Real { unit 'min'; }
        value def Frequency :> Real { unit 'MHz'; }
        value def Impedance :> Real { unit 'ohm'; }
        value def DutyCycle :> Real { unit '%'; }
        value def Voltage :> Real { unit 'V'; }
        value def Current :> Real { unit 'A'; }
        value def FlowRate :> Real { unit 'L/min'; }
    }
    use Units::*;

    // ===== Item Definitions =====
    item def RFEnergy {
        attribute frequency : Frequency;
        attribute power : PowerLevel;
    }
    item def ThermalEnergy;
    item def CoolingFluid {
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
    }
    item def TempReading {
        attribute value : Temperature;
    }
    item def ImpedanceReading {
        attribute value : Impedance;
    }
    item def ControlCommand {
        attribute targetPower : PowerLevel;
        attribute mode : OperatingMode;
    }
    item def StatusReport {
        attribute systemState : String;
        attribute currentPower : PowerLevel;
        attribute tissueTemp : Temperature;
        attribute contactImpedance : Impedance;
    }
    item def FaultSignal {
        attribute faultType : String;
        attribute severity : Integer;
    }

    // ===== Enumerations =====
    enum def OperatingMode { continuous; pulsed; }
    enum def SystemState { idle; warmup; activeTreatment; fault; }

    // ===== Port Definitions =====
    port def RFEnergyOut { out item rfEnergy : RFEnergy; }
    port def RFEnergyIn { in item rfEnergy : RFEnergy; }
    port def TempFeedbackOut { out item tempReading : TempReading; }
    port def TempFeedbackIn { in item tempReading : TempReading; }
    port def ImpedanceFeedbackOut { out item impedanceReading : ImpedanceReading; }
    port def ImpedanceFeedbackIn { in item impedanceReading : ImpedanceReading; }
    port def ControlCmdOut { out item command : ControlCommand; }
    port def ControlCmdIn { in item command : ControlCommand; }
    port def StatusOut { out item status : StatusReport; }
    port def StatusIn { in item status : StatusReport; }
    port def FaultOut { out item fault : FaultSignal; }
    port def FaultIn { in item fault : FaultSignal; }
    port def CoolingFluidOut { out item coolant : CoolingFluid; }
    port def CoolingFluidIn { in item coolant : CoolingFluid; }
    port def ThermalEnergyOut { out item heat : ThermalEnergy; }
    port def ThermalEnergyIn { in item heat : ThermalEnergy; }

    // ===== Part Definitions =====
    part def RFFrequencyGenerator {
        attribute maxPower : PowerLevel = 500;
        attribute operatingFrequency : Frequency = 27.12;
        port rfOut : RFEnergyOut;
        port cmdIn : ControlCmdIn;
        port statusOut : StatusOut;
        attribute currentPower : PowerLevel;
        attribute currentMode : OperatingMode;

        action def generateRF {
            in cmd : ControlCommand;
            out energy : RFEnergy;
        }
        exhibit action generateRF(
            in cmd = cmdIn.command,
            out energy = rfOut.rfEnergy
        );
    }

    part def Applicator {
        attribute applicatorType : String = "capacitive plate";
        port rfIn : RFEnergyIn;
        port thermalOut : ThermalEnergyOut;
        port coolingIn : CoolingFluidIn;
        port impedanceOut : ImpedanceFeedbackOut;
        attribute contactArea : Real;
        attribute couplingEfficiency : Real = 0.85;

        action def deliverEnergy {
            in rf : RFEnergy;
            out heat : ThermalEnergy;
            out impedance : ImpedanceReading;
        }
        exhibit action deliverEnergy(
            in rf = rfIn.rfEnergy,
            out heat = thermalOut.heat,
            out impedance = impedanceOut.impedanceReading
        );
    }

    part def TemperatureSensor {
        attribute measurementRangeMin : Temperature = 20;
        attribute measurementRangeMax : Temperature = 60;
        attribute accuracy : Real = 0.1;
        port tempOut : TempFeedbackOut;

        action def measureTemperature {
            out reading : TempReading;
        }
        exhibit action measureTemperature(
            out reading = tempOut.tempReading
        );
    }

    part def ImpedanceMonitor {
        attribute acceptableRangeMin : Impedance = 20;
        attribute acceptableRangeMax : Impedance = 500;
        port impedanceIn : ImpedanceFeedbackIn;
        port impedanceOut : ImpedanceFeedbackOut;
        attribute currentImpedance : Impedance;
        attribute contactQuality : String;

        action def evaluateContact {
            in reading : ImpedanceReading;
            out evaluated : ImpedanceReading;
        }
        exhibit action evaluateContact(
            in reading = impedanceIn.impedanceReading,
            out evaluated = impedanceOut.impedanceReading
        );
    }

    part def ControlUnit {
        attribute targetTemperature : Temperature = 42;
        attribute minTherapeuticTemp : Temperature = 40;
        attribute maxTherapeuticTemp : Temperature = 45;
        attribute setPower : PowerLevel;
        attribute setDuration : Duration;
        attribute setMode : OperatingMode;
        attribute elapsedTime : Duration;
        attribute currentTissueTemp : Temperature;
        attribute currentImpedance : Impedance;
        port tempIn : TempFeedbackIn;
        port impedanceIn : ImpedanceFeedbackIn;
        port rfCmdOut : ControlCmdOut;
        port statusOut : StatusOut;
        port faultIn : FaultIn;
        port interlockCmdOut : ControlCmdOut;

        action def regulatePower {
            in temp : TempReading;
            in impedance : ImpedanceReading;
            out cmd : ControlCommand;
        }
        exhibit action regulatePower(
            in temp = tempIn.tempReading,
            in impedance = impedanceIn.impedanceReading,
            out cmd = rfCmdOut.command
        );

        action def reportStatus {
            out status : StatusReport;
        }
        exhibit action reportStatus(
            out status = statusOut.status
        );
    }

    part def SafetyInterlock {
        attribute maxTreatmentTime : Duration = 30;
        attribute maxTissueTemp : Temperature = 45;
        attribute maxImpedance : Impedance = 500;
        attribute minImpedance : Impedance = 20;
        attribute faultDetected : Boolean = false;
        port statusIn : StatusIn;
        port tempIn : TempFeedbackIn;
        port impedanceIn : ImpedanceFeedbackIn;
        port faultOut : FaultOut;

        action def monitorSafety {
            in status : StatusReport;
            in temp : TempReading;
            in impedance : ImpedanceReading;
            out fault : FaultSignal;
        }
        exhibit action monitorSafety(
            in status = statusIn.status,
            in temp = tempIn.tempReading,
            in impedance = impedanceIn.impedanceReading,
            out fault = faultOut.fault
        );

        action def shutdown {
            attribute shutdownInitiated : Boolean;
        }
    }

    part def CoolingSystem {
        attribute coolantFlowRate : FlowRate = 2.0;
        attribute coolantTemp : Temperature = 15;
        attribute maxFlowRate : FlowRate = 5.0;
        port coolantOut : CoolingFluidOut;

        action def circulateCoolant {
            out fluid : CoolingFluid;
        }
        exhibit action circulateCoolant(
            out fluid = coolantOut.coolant
        );
    }

    part def Patient {
        attribute bodyTissueTemp : Temperature = 37;
        port thermalIn : ThermalEnergyIn;
        port skinSurfaceTemp : Temperature;
    }

    // ===== System State Machine =====
    state def DiathermySystemStateMachine {
        entry; then idle;
        state idle;
        state warmup;
        state activeTreatment;
        state fault;

        transition idle_to_warmup
            first idle
            if (operatorStartCommand)
            then warmup;
        transition warmup_to_active
            first warmup
            if (warmupComplete)
            then activeTreatment;
        transition active_to_idle
            first activeTreatment
            if (treatmentComplete)
            then idle;
        transition any_to_fault
            first {
                idle, warmup, activeTreatment
            }
            if (faultDetected)
            then fault;
        transition fault_to_idle
            first fault
            if (faultCleared)
            then idle;
    }

    // ===== Top-Level System =====
    part def DiathermyTherapySystem {
        attribute systemName : String = "Medical Diathermy Therapy System";
        attribute systemState : SystemState;
        attribute therapeuticTempMin : Temperature = 40;
        attribute therapeuticTempMax : Temperature = 45;
        attribute operatingFrequency : Frequency = 27.12;

        port externalTempFeedback : TempFeedbackIn;
        port externalImpedanceFeedback : ImpedanceFeedbackIn;
        port externalStatus : StatusOut;
        port externalFault : FaultOut;

        part rfGenerator : RFFrequencyGenerator {
            port rfOut : RFEnergyOut;
            port cmdIn : ControlCmdIn;
            port statusOut : StatusOut;
        }
        part applicator : Applicator {
            port rfIn : RFEnergyIn;
            port thermalOut : ThermalEnergyOut;
            port coolingIn : CoolingFluidIn;
            port impedanceOut : ImpedanceFeedbackOut;
        }
        part tempSensor : TemperatureSensor {
            port tempOut : TempFeedbackOut;
        }
        part impedanceMonitor : ImpedanceMonitor {
            port impedanceIn : ImpedanceFeedbackIn;
            port impedanceOut : ImpedanceFeedbackOut;
        }
        part controlUnit : ControlUnit {
            port tempIn : TempFeedbackIn;
            port impedanceIn : ImpedanceFeedbackIn;
            port rfCmdOut : ControlCmdOut;
            port statusOut : StatusOut;
            port faultIn : FaultIn;
            port interlockCmdOut : ControlCmdOut;
        }
        part safetyInterlock : SafetyInterlock {
            port statusIn : StatusIn;
            port tempIn : TempFeedbackIn;
            port impedanceIn : ImpedanceFeedbackIn;
            port faultOut : FaultOut;
        }
        part coolingSystem : CoolingSystem {
            port coolantOut : CoolingFluidOut;
        }
        part patient : Patient {
            port thermalIn : ThermalEnergyIn;
        }

        // Connections
        connection rfEnergyDelivery connect rfGenerator.rfOut to applicator.rfIn;
        connection thermalDelivery connect applicator.thermalOut to patient.thermalIn;
        connection tempFeedback connect tempSensor.tempOut to controlUnit.tempIn;
        connection tempFeedbackInterlock connect tempSensor.tempOut to safetyInterlock.tempIn;
        connection impedanceFeedback connect applicator.impedanceOut to impedanceMonitor.impedanceIn;
        connection impedanceToControl connect impedanceMonitor.impedanceOut to controlUnit.impedanceIn;
        connection impedanceToInterlock connect impedanceMonitor.impedanceOut to safetyInterlock.impedanceIn;
        connection controlToRF connect controlUnit.rfCmdOut to rfGenerator.cmdIn;
        connection statusToInterlock connect rfGenerator.statusOut to safetyInterlock.statusIn;
        connection statusReport connect controlUnit.statusOut to externalStatus;
        connection faultSignal connect safetyInterlock.faultOut to controlUnit.faultIn;
        connection faultExternal connect safetyInterlock.faultOut to externalFault;
        connection coolantDelivery connect coolingSystem.coolantOut to applicator.coolingIn;

        // State machine behavior
        exhibit state machine DiathermySystemStateMachine {
            entry; then idle;
            state idle {
                entry attribute systemState = SystemState::idle;
            }
            state warmup {
                entry attribute systemState = SystemState::warmup;
            }
            state activeTreatment {
                entry attribute systemState = SystemState::activeTreatment;
            }
            state fault {
                entry attribute systemState = SystemState::fault;
            }
            transition first idle if (operatorStartCommand) then warmup;
            transition first warmup if (warmupComplete) then activeTreatment;
            transition first activeTreatment if (treatmentComplete) then idle;
            transition first { idle, warmup, activeTreatment } if (faultDetected) then fault;
            transition first fault if (faultCleared) then idle;
        }
    }

    // ===== Requirements =====
    requirement def DeepTissueHeatingRequirement {
        subject system : DiathermyTherapySystem;
        attribute requiredTempMin : Temperature = 40;
        attribute requiredTempMax : Temperature = 45;
        doc /* The system shall deliver controlled deep tissue heating to maintain therapeutic temperature between 40 and 45 degrees Celsius. */
        require system.therapeuticTempMin >= requiredTempMin;
        require system.therapeuticTempMax <= requiredTempMax;
    }

    requirement def RFGenerationRequirement {
        subject generator : RFFrequencyGenerator;
        attribute requiredFrequency : Frequency = 27.12;
        attribute requiredMaxPower : PowerLevel = 500;
        doc /* The RF Generator shall produce high-frequency electromagnetic energy at 27.12 MHz with up to 500 W power. */
        require generator.operatingFrequency == requiredFrequency;
        require generator.maxPower >= requiredMaxPower;
    }

    requirement def TemperatureControlRequirement {
        subject control : ControlUnit;
        attribute targetTemp : Temperature = 42;
        attribute tolerance : Real = 3.0;
        doc /* The Control Unit shall automatically adjust power output to maintain tissue temperature within the therapeutic range. */
        require control.targetTemperature >= control.minTherapeuticTemp;
        require control.targetTemperature <= control.maxTherapeuticTemp;
    }

    requirement def ImpedanceMonitoringRequirement {
        subject monitor : ImpedanceMonitor;
        doc /* The Impedance Monitor shall detect poor coupling between the applicator and patient skin. */
        require monitor.acceptableRangeMin >= 20;
        require monitor.acceptableRangeMax <= 500;
    }

    requirement def SafetyInterlockRequirement {
        subject interlock : SafetyInterlock;
        attribute maxTime : Duration = 30;
        attribute maxTemp : Temperature = 45;
        doc /* The Safety Interlock shall automatically shut down the system upon detecting overheating, poor contact, or treatment time exceeded. */
        require interlock.maxTreatmentTime <= maxTime;
        require interlock.maxTissueTemp <= maxTemp;
    }

    requirement def CoolingRequirement {
        subject cooling : CoolingSystem;
        attribute maxCoolantTemp : Temperature = 20;
        doc /* The Cooling System shall maintain the patient's skin surface at a comfortable temperature during treatment. */
        require cooling.coolantTemp <= maxCoolantTemp;
    }

    requirement def StateMachineRequirement {
        subject system : DiathermyTherapySystem;
        doc /* The system shall operate through idle, warmup, active treatment, and fault states. */
        require system.systemState in { SystemState::idle, SystemState::warmup, SystemState::activeTreatment, SystemState::fault };
    }

    requirement def SystemRequirements {
        subject system : DiathermyTherapySystem;
        satisfy DeepTissueHeatingRequirement;
        satisfy RFGenerationRequirement;
        satisfy TemperatureControlRequirement;
        satisfy ImpedanceMonitoringRequirement;
        satisfy SafetyInterlockRequirement;
        satisfy CoolingRequirement;
        satisfy StateMachineRequirement;
    }
}
