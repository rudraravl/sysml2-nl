package AspirationTherapySystem {

    // ===== Value Types with Units =====
    
    package Units {
        import ISQ::Volume;
        import ISQ::Time;
        import ISQ::Pressure;
        
        value type Milliliter :> Volume { 
            attribute unit : String = "mL"; 
        }
        value type Minute :> Time { 
            attribute unit : String = "min"; 
        }
        value type Second :> Time { 
            attribute unit : String = "s"; 
        }
        value type Millibar :> Pressure { 
            attribute unit : String = "mbar"; 
        }
        value type Percent :> Real { 
            attribute unit : String = "%"; 
        }
    }
    
    import Units::*;
    
    // ===== Item Types =====
    
    item def GastricContents {
        attribute volume : Milliliter;
        attribute description : String;
    }
    
    item def AspiratedContents :> GastricContents {
        attribute pH : Real;
        attribute caloricEstimate : Real;
    }
    
    // ===== Port Definitions =====
    
    port def VacuumPort {
        attribute pressure : Millibar;
        out vacuumFlow : AspiratedContents;
    }
    
    port def FluidPort {
        in fluidFlow : AspiratedContents;
        attribute flowRate : Milliliter;
    }
    
    port def SignalPort {
        attribute signalValue : Real;
        attribute signalType : String;
    }
    
    port def DataPort {
        attribute dataPayload : String;
        attribute timestamp : Second;
    }
    
    // ===== Requirements =====
    
    requirement def SafeVacuumLimit {
        doc /* The vacuum pressure must not exceed physiologically safe limits to prevent tissue damage. */
        attribute maxSafeVacuum : Millibar = 150;
        attribute minOperatingVacuum : Millibar = 50;
        constraint { pressure >= minOperatingVacuum and pressure <= maxSafeVacuum }
        subject pressure : Millibar;
    }
    
    requirement def SessionTerminationCondition {
        doc /* Session must terminate when target volume reached or max duration met. */
        attribute targetVolume : Milliliter = 500;
        attribute maxDuration : Minute = 20;
        constraint { removedVolume >= targetVolume or elapsedTime >= maxDuration }
        subject removedVolume : Milliliter;
        subject elapsedTime : Minute;
    }
    
    requirement def SafetyHoldTrigger {
        doc /* If any safety parameter is breached, the device enters Safety Hold and alerts the user. */
        constraint { pressure > maxSafeVacuum or reservoirFillLevel > 95 or elapsedTime > maxDuration }
        subject pressure : Millibar;
        subject reservoirFillLevel : Percent;
        subject elapsedTime : Minute;
        subject maxSafeVacuum : Millibar;
        subject maxDuration : Minute;
    }
    
    requirement def AspirationTherapyRequirement {
        doc /* The system shall remove a portion of gastric contents from a patient's stomach after a meal to reduce caloric absorption. */
        satisfy SafeVacuumLimit;
        satisfy SessionTerminationCondition;
        satisfy SafetyHoldTrigger;
    }
    
    // ===== Component Definitions =====
    
    part def TherapyControlUnit {
        port controlSignalOut : SignalPort;
        port controlSignalIn : SignalPort;
        port uiDataOut : DataPort;
        port uiDataIn : DataPort;
        port monitorDataIn : DataPort;
        port reservoirDataIn : DataPort;
        
        attribute targetVolume : Milliliter = 500;
        attribute maxSessionDuration : Minute = 20;
        attribute targetVacuumPressure : Millibar = 100;
        attribute currentRemovedVolume : Milliliter := 0;
        attribute currentElapsedTime : Minute := 0;
        attribute currentPressure : Millibar := 0;
        attribute currentReservoirFill : Percent := 0;
        
        exhibit state ControlStateMachine {
            entry; then standby;
            
            state standby {
                entry; 
                /* System powered on, awaiting configuration. */
            }
            
            transition standby_to_preparation
                first standby
                then preparation
                when uiDataIn.dataPayload == "start_session";
            
            state preparation {
                entry;
                /* Verify all connections are secure. */
                do send ControlSignal(signalValue := 1, signalType := "check_connections") to controlSignalOut;
            }
            
            transition preparation_to_active
                first preparation
                then activeAspiration
                when monitorDataIn.dataPayload == "connections_verified";
            
            state activeAspiration {
                entry;
                do send ControlSignal(signalValue := targetVacuumPressure, signalType := "activate_vacuum") to controlSignalOut;
                
                parallel {
                    state suctionCycle {
                        entry;
                        do send ControlSignal(signalValue := targetVacuumPressure, signalType := "suction_on") to controlSignalOut;
                        then wait;
                    }
                    state wait {
                        entry;
                        do send ControlSignal(signalValue := 0, signalType := "suction_off") to controlSignalOut;
                        then suctionCycle;
                    }
                }
            }
            
            transition active_to_safetyHold_pressure
                first activeAspiration
                then safetyHold
                when currentPressure > 150;
            
            transition active_to_safetyHold_reservoir
                first activeAspiration
                then safetyHold
                when currentReservoirFill > 95;
            
            transition active_to_safetyHold_time
                first activeAspiration
                then safetyHold
                when currentElapsedTime > maxSessionDuration;
            
            transition active_to_standby_volume
                first activeAspiration
                then standby
                when currentRemovedVolume >= targetVolume;
            
            transition active_to_standby_time
                first activeAspiration
                then standby
                when currentElapsedTime >= maxSessionDuration;
            
            state safetyHold {
                entry;
                do send ControlSignal(signalValue := 0, signalType := "emergency_stop") to controlSignalOut;
                do send ControlSignal(signalValue := 1, signalType := "alert_user") to uiDataOut;
            }
            
            transition safetyHold_to_standby
                first safetyHold
                then standby
                when uiDataIn.dataPayload == "reset";
        }
        
        action performSafetyCheck {
            in pressure : Millibar;
            in reservoirFill : Percent;
            in elapsedTime : Minute;
            out safe : Boolean;
            
            if pressure > 150 | reservoirFill > 95 | elapsedTime > maxSessionDuration {
                assign safe = false;
            } else {
                assign safe = true;
            }
        }
    }
    
    part def VacuumGenerationUnit {
        port vacuumControlIn : SignalPort;
        port vacuumOut : VacuumPort;
        
        attribute generatedPressure : Millibar := 0;
        attribute maxPressure : Millibar = 200;
        attribute pumpActive : Boolean := false;
        
        exhibit state PumpStateMachine {
            entry; then idle;
            
            state idle {
                entry;
                assign pumpActive = false;
                assign generatedPressure = 0;
            }
            
            transition idle_to_running
                first idle
                then running
                when vacuumControlIn.signalType == "activate_vacuum" or vacuumControlIn.signalType == "suction_on";
            
            state running {
                entry;
                assign pumpActive = true;
                assign generatedPressure = vacuumControlIn.signalValue;
                do send VacuumFlow(pressure := generatedPressure) to vacuumOut;
            }
            
            transition running_to_idle
                first running
                then idle
                when vacuumControlIn.signalType == "suction_off" or vacuumControlIn.signalType == "emergency_stop";
            }
    }
    
    part def AspirationCatheterAssembly {
        port vacuumIn : VacuumPort;
        port fluidOut : FluidPort;
        port patientInterface : VacuumPort;
        
        attribute catheterLength : Milliliter := 0;
        attribute tubeDiameter : Milliliter := 0;
        attribute isSecure : Boolean := false;
        attribute flowRate : Milliliter := 10;
        
        action transferContents {
            in incomingContents : AspiratedContents;
            out outgoingContents : AspiratedContents;
            
            assign outgoingContents = incomingContents;
        }
    }
    
    part def PressureMonitoringSubsystem {
        port pressureSensorIn : VacuumPort;
        port monitorDataOut : DataPort;
        
        attribute measuredPressure : Millibar := 0;
        attribute samplingInterval : Second := 1;
        attribute upperSafeLimit : Millibar = 150;
        attribute lowerSafeLimit : Millibar = 50;
        attribute alarmActive : Boolean := false;
        
        action measurePressure {
            in sensorInput : Millibar;
            out measuredValue : Millibar;
            out alarmFlag : Boolean;
            
            assign measuredValue = sensorInput;
            
            if sensorInput > upperSafeLimit | sensorInput < lowerSafeLimit {
                assign alarmFlag = true;
            } else {
                assign alarmFlag = false;
            }
        }
        
        action transmitData {
            in pressure : Millibar;
            in alarm : Boolean;
            out data : String;
            
            if alarm {
                assign data = "pressure_alarm";
            } else {
                assign data = "pressure_normal";
            }
        }
    }
    
    part def CollectionReservoir {
        port fluidIn : FluidPort;
        port reservoirDataOut : DataPort;
        
        attribute capacity : Milliliter = 1000;
        attribute currentFillLevel : Milliliter := 0;
        attribute fillPercentage : Percent := 0;
        attribute isFull : Boolean := false;
        attribute disposalRequired : Boolean := false;
        
        action collectContents {
            in incoming : AspiratedContents;
            
            assign currentFillLevel = currentFillLevel + incoming.volume;
            assign fillPercentage = (currentFillLevel / capacity) * 100;
            
            if fillPercentage >= 95 {
                assign isFull = true;
                assign disposalRequired = true;
            }
        }
        
        action reportFillLevel {
            out data : String;
            
            if isFull {
                assign data = "reservoir_full";
            } else {
                assign data = "reservoir_ok";
            }
        }
    }
    
    part def UserInterfaceModule {
        port uiDataOut : DataPort;
        port uiDataIn : DataPort;
        
        attribute configuredTargetVolume : Milliliter := 500;
        attribute configuredMaxDuration : Minute := 20;
        attribute configuredVacuumPressure : Millibar := 100;
        attribute displayStatus : String := "Standby";
        attribute alertActive : Boolean := false;
        
        action configureSession {
            in targetVol : Milliliter;
            in maxDur : Minute;
            in vacuumPres : Millibar;
            out configData : String;
            
            assign configuredTargetVolume = targetVol;
            assign configuredMaxDuration = maxDur;
            assign configuredVacuumPressure = vacuumPres;
            assign configData = "session_configured";
        }
        
        action displayStatusUpdate {
            in statusData : String;
            
            assign displayStatus = statusData;
            
            if statusData == "alert_user" {
                assign alertActive = true;
            }
        }
    }
    
    // ===== Top-Level System Assembly =====
    
    part def AspirationTherapyDevice {
        part controlUnit : TherapyControlUnit;
        part vacuumUnit : VacuumGenerationUnit;
        part catheter : AspirationCatheterAssembly;
        part pressureMonitor : PressureMonitoringSubsystem;
        part reservoir : CollectionReservoir;
        part userInterface : UserInterfaceModule;
        
        // Connections between components
        connection controlToVacuum connect controlUnit.controlSignalOut to vacuumUnit.vacuumControlIn;
        connection vacuumToCatheter connect vacuumUnit.vacuumOut to catheter.vacuumIn;
        connection catheterToReservoir connect catheter.fluidOut to reservoir.fluidIn;
        connection catheterToPressureMonitor connect catheter.vacuumIn to pressureMonitor.pressureSensorIn;
        connection pressureMonitorToControl connect pressureMonitor.monitorDataOut to controlUnit.monitorDataIn;
        connection reservoirToControl connect reservoir.reservoirDataOut to controlUnit.reservoirDataIn;
        connection controlToUI connect controlUnit.uiDataOut to userInterface.uiDataIn;
        connection uiToControl connect userInterface.uiDataOut to controlUnit.uiDataIn;
        
        // Patient interface connection
        connection catheterToPatient connect catheter.patientInterface to patientStomach;
        
        part patientStomach :> GastricContents {
            attribute stomachVolume : Milliliter := 800;
        }
        
        satisfy AspirationTherapyRequirement by controlUnit;
        satisfy SafeVacuumLimit by pressureMonitor;
        satisfy SessionTerminationCondition by controlUnit;
        satisfy SafetyHoldTrigger by controlUnit;
    }
    
    // ===== Item Flows =====
    
    item flow aspiratedFlow : AspiratedContents from vacuumUnit.vacuumOut to catheter.vacuumIn;
    item flow catheterFlow : AspiratedContents from catheter.fluidOut to reservoir.fluidIn;
    
    // ===== Signal Definitions =====
    
    item def ControlSignal {
        attribute signalValue : Real;
        attribute signalType : String;
    }
    
    item def VacuumFlow {
        attribute pressure : Millibar;
    }
    
}
