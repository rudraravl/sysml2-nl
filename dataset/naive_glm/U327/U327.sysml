package NPWT_System {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def PressureValue :> Real {
        unit 'mmHg';
    }
    value def FlowRateValue :> Real {
        unit 'mL/min';
    }
    value def VolumeValue :> Real {
        unit 'mL';
    }
    value def DurationValue :> Real {
        unit 'h';
    }
    value def PowerValue :> Real {
        unit 'W';
    }
    value def VoltageValue :> Real {
        unit 'V';
    }
    value def FrequencyValue :> Real {
        unit 'Hz';
    }

    // ===== Item Types =====
    item def Exudate {
        attribute viscosity : Real;
        attribute density : Real;
    }
    item def Air;
    item def AlarmSignal {
        attribute frequency : FrequencyValue;
        attribute volume : Real;
    }
    item def ControlCommand {
        attribute commandType : String;
    }
    item def PressureReading {
        attribute measuredPressure : PressureValue;
    }
    item def FluidLevelReading {
        attribute level : VolumeValue;
        attribute isFull : Boolean;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        out item exudate : Exudate;
        in item air : Air;
    }
    port def VacuumPort {
        out item air : Air;
        in item exudate : Exudate;
    }
    port def PressureSignalPort {
        out item reading : PressureReading;
    }
    port def FluidLevelSignalPort {
        out item reading : FluidLevelReading;
    }
    port def ControlPort {
        in item command : ControlCommand;
        out item status : String;
    }
    port def AlarmPort {
        out item signal : AlarmSignal;
    }
    port def PowerPort {
        in attribute voltage : VoltageValue;
    }

    // ===== Requirements =====
    requirement def TherapeuticPressureRequirement {
        doc /* The system shall maintain a controlled continuous vacuum at the wound site. */
        attribute targetPressure : PressureValue = -125 [mmHg];
        attribute tolerance : PressureValue = 10 [mmHg];
        constraint { targetPressure >= -200 [mmHg] and targetPressure <= -50 [mmHg] }
    }
    requirement def LeakDetectionRequirement {
        doc /* The system shall detect air leaks that prevent target pressure maintenance and activate an alarm. */
        constraint { leakDetected implies alarmActive }
    }
    requirement def CanisterFullRequirement {
        doc /* The system shall alert a caregiver when the canister is nearly full. */
        attribute fullThreshold : VolumeValue = 400 [mL];
        constraint { fluidLevel >= fullThreshold implies alarmActive }
    }
    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate continuously over several days. */
        attribute minOperationDuration : DurationValue = 72 [h];
    }
    requirement def SafetyAlarmRequirement {
        doc /* The system shall provide an audible alarm for safety-critical events. */
        attribute minAlarmVolume : Real = 65;
        constraint { alarmVolume >= minAlarmVolume }
    }

    // ===== Components =====
    part def WoundDressing {
        attribute sealIntegrity : Boolean = true;
        port vacuumInterface : VacuumPort;
        attribute appliedArea : Real;
        
        action def ApplyDressing {
            in woundSite : String;
        }
        action def CreateSeal {
            out sealCreated : Boolean;
        }
        perform action apply : ApplyDressing;
        perform action seal : CreateSeal;
    }

    part def ExudateCanister {
        attribute capacity : VolumeValue = 450 [mL];
        attribute currentLevel : VolumeValue = 0 [mL];
        attribute isFull : Boolean = false;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port levelReport : FluidLevelSignalPort;
        
        action def CollectFluid {
            in exudate : Exudate;
            out level : VolumeValue;
        }
        action def CheckLevel {
            out isFull : Boolean;
        }
        perform action collect : CollectFluid;
        perform action check : CheckLevel;
    }

    part def VacuumPump {
        attribute maxVacuum : PressureValue = -200 [mmHg];
        attribute powerConsumption : PowerValue = 15 [W];
        attribute isRunning : Boolean = false;
        port powerIn : PowerPort;
        port vacuumOut : VacuumPort;
        port controlIn : ControlPort;
        
        action def StartPump {
            out running : Boolean;
        }
        action def StopPump {
            out running : Boolean;
        }
        action def GenerateVacuum {
            out pressure : PressureValue;
        }
        perform action start : StartPump;
        perform action stop : StopPump;
        perform action generate : GenerateVacuum;
    }

    part def PressureSensor {
        attribute accuracy : PressureValue = 2 [mmHg];
        attribute samplingRate : FrequencyValue = 10 [Hz];
        port pressureOut : PressureSignalPort;
        port sensingPort : VacuumPort;
        
        action def MeasurePressure {
            out reading : PressureReading;
        }
        perform action measure : MeasurePressure;
    }

    part def FluidLevelSensor {
        port levelOut : FluidLevelSignalPort;
        
        action def DetectLevel {
            out reading : FluidLevelReading;
        }
        perform action detect : DetectLevel;
    }

    part def AlarmUnit {
        attribute alarmActive : Boolean = false;
        attribute alarmVolume : Real = 70;
        port alarmIn : ControlPort;
        port alarmOut : AlarmPort;
        
        action def TriggerAlarm {
            in reason : String;
            out signal : AlarmSignal;
        }
        action def SilenceAlarm {
            out silenced : Boolean;
        }
        perform action trigger : TriggerAlarm;
        perform action silence : SilenceAlarm;
    }

    part def ControlModule {
        attribute targetPressure : PressureValue = -125 [mmHg];
        attribute tolerance : PressureValue = 10 [mmHg];
        attribute leakDetected : Boolean = false;
        attribute currentMode : String = "Off";
        port pressureIn : PressureSignalPort;
        port fluidLevelIn : FluidLevelSignalPort;
        port pumpControl : ControlPort;
        port alarmControl : ControlPort;
        port powerIn : PowerPort;
        
        action def EvaluatePressure {
            in reading : PressureReading;
            out command : ControlCommand;
        }
        action def EvaluateFluidLevel {
            in reading : FluidLevelReading;
            out command : ControlCommand;
        }
        action def DetectLeak {
            in reading : PressureReading;
            out leakDetected : Boolean;
        }
        action def RegulatePump {
            in currentPressure : PressureValue;
            out command : ControlCommand;
        }
        perform action evaluatePressure : EvaluatePressure;
        perform action evaluateFluidLevel : EvaluateFluidLevel;
        perform action detectLeak : DetectLeak;
        perform action regulate : RegulatePump;
        
        state def ControlBehavior {
            entry; then Off;
            state Off;
            state Initializing {
                entry action initializeSystem {
                    /* Perform self-test and calibration */
                }
                do action waitForStabilization;
                transition from Off to Initializing
                    when powerApplied;
                transition from Initializing to Active
                    when initializationComplete;
            }
            state Active {
                entry action startTherapy {
                    /* Activate pump and begin monitoring */
                }
                do action maintainPressure;
                transition from Active to Paused
                    when alarmTriggered or leakDetected or canisterFull;
                transition from Active to Shutdown
                    when therapyComplete or shutdownCommanded;
            }
            state Paused {
                entry action pauseTherapy {
                    /* Deactivate pump, await resolution */
                }
                do action monitorConditions;
                transition from Paused to Active
                    when alarmResolved and not canisterFull;
                transition from Paused to Shutdown
                    when shutdownCommanded;
            }
            state Shutdown {
                entry action performShutdown {
                    /* Safely stop pump and power down */
                }
                do action finalize;
                transition from Shutdown to Off
                    when shutdownComplete;
            }
        }
        perform state behavior : ControlBehavior;
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 12 [V];
        attribute batteryCapacity : Real = 5000;
        port powerOut : PowerPort;
        
        action def SupplyPower {
            out voltage : VoltageValue;
        }
        perform action supply : SupplyPower;
    }

    part def NPWTDevice {
        attribute deviceSerial : String;
        attribute therapyDuration : DurationValue = 72 [h];
        
        part dressing : WoundDressing;
        part canister : ExudateCanister;
        part pump : VacuumPump;
        part pressureSensor : PressureSensor;
        part fluidLevelSensor : FluidLevelSensor;
        part controlModule : ControlModule;
        part alarmUnit : AlarmUnit;
        part powerSupply : PowerSupply;
        
        // Connections
        connection def FluidPath {
            end source : FluidPort;
            end target : VacuumPort;
        }
        connection def PressureFeedback {
            end source : PressureSignalPort;
            end target : ControlPort;
        }
        connection def FluidLevelFeedback {
            end source : FluidLevelSignalPort;
            end target : ControlPort;
        }
        connection def PumpControlLink {
            end source : ControlPort;
            end target : ControlPort;
        }
        connection def AlarmControlLink {
            end source : ControlPort;
            end target : ControlPort;
        }
        connection def PowerLink {
            end source : PowerPort;
            end target : PowerPort;
        }
        connection def VacuumLink {
            end source : VacuumPort;
            end target : VacuumPort;
        }
        
        connection fluidConn : FluidPath connect dressing.vacuumInterface to canister.fluidIn;
        connection vacuumConn : VacuumLink connect canister.fluidOut to pump.vacuumOut;
        connection pressureConn : PressureFeedback connect pressureSensor.pressureOut to controlModule.pressureIn;
        connection sensorVacuumConn : VacuumLink connect dressing.vacuumInterface to pressureSensor.sensingPort;
        connection fluidLevelConn : FluidLevelFeedback connect fluidLevelSensor.levelOut to controlModule.fluidLevelIn;
        connection canisterLevelConn : FluidLevelFeedback connect canister.levelReport to controlModule.fluidLevelIn;
        connection pumpControlConn : PumpControlLink connect controlModule.pumpControl to pump.controlIn;
        connection alarmControlConn : AlarmControlLink connect controlModule.alarmControl to alarmUnit.alarmIn;
        connection powerToPump : PowerLink connect powerSupply.powerOut to pump.powerIn;
        connection powerToControl : PowerLink connect powerSupply.powerOut to controlModule.powerIn;
        
        // Requirement satisfactions
        satisfy therapeuticReq : TherapeuticPressureRequirement by controlModule.targetPressure;
        satisfy leakReq : LeakDetectionRequirement by controlModule.detectLeak;
        satisfy canisterReq : CanisterFullRequirement by canister.currentLevel;
        satisfy continuousReq : ContinuousOperationRequirement by therapyDuration;
        satisfy alarmReq : SafetyAlarmRequirement by alarmUnit.alarmVolume;
    }

    // ===== Top-level usage =====
    part npwtSystem : NPWTDevice {
        attribute patientId : String;
        attribute clinicianPrescribedPressure : PressureValue = -125 [mmHg];
    }

}
