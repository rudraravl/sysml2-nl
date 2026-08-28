package IndustrialDielectricHeatingSystem {

    import ScalarValues::*;

    // ============================================================
    // Value Types
    // ============================================================

    value type PowerW :> Real { unit 'W'; }
    value type TempC :> Real { unit 'degC'; }
    value type FreqMHz :> Real { unit 'MHz'; }
    value type TimeS :> Real { unit 's'; }
    value type FlowLpm :> Real { unit 'L/min'; }
    value type VoltV :> Real { unit 'V'; }
    value type Percent :> Real { unit '%'; }

    // ============================================================
    // Item Types
    // ============================================================

    item def RFEnergy;
    item def Coolant;
    item def Workpiece;

    // ============================================================
    // Port Definitions
    // ============================================================

    port def RFEnergyOutPort {
        out item rfEnergy : RFEnergy;
        attribute powerLevel : PowerW;
    }

    port def RFEnergyInPort {
        in item rfEnergy : RFEnergy;
        attribute powerLevel : PowerW;
    }

    port def TempReadingPort {
        out attribute measuredTemp : TempC;
    }

    port def PowerCmdPort {
        in attribute commandedPower : PowerW;
    }

    port def CoolantFlowPort {
        out item coolant : Coolant;
        attribute flowRate : FlowLpm;
        attribute supplyTemp : TempC;
    }

    port def CoolantReturnPort {
        in item coolant : Coolant;
        attribute returnTemp : TempC;
    }

    port def SafetyStatusPort {
        out attribute systemSafe : Boolean;
        out attribute faultId : Integer;
    }

    port def SafetyCmdPort {
        in attribute shutdownCmd : Boolean;
    }

    port def UserCmdPort {
        in attribute targetTemp : TempC;
        in attribute holdTime : TimeS;
        in attribute start : Boolean;
        in attribute stop : Boolean;
    }

    // ============================================================
    // Requirement Definitions
    // ============================================================

    requirement def UniformHeatingReq {
        doc "The system shall heat non-conductive materials uniformly using high-frequency electromagnetic energy.";
        attribute targetFrequency : FreqMHz = 27.12;
        attribute maxTempGradient : TempC = 5.0;
    }

    requirement def PowerGenerationReq {
        doc "The RF Power Generator shall produce adjustable high-frequency electromagnetic power.";
        attribute nominalFrequency : FreqMHz = 27.12;
        attribute maxPower : PowerW = 50000;
        attribute minPower : PowerW = 0;
    }

    requirement def TempControlReq {
        doc "The Heating Controller shall maintain material temperature within tolerance of the target using PID control.";
        attribute tolerance : TempC = 2.0;
    }

    requirement def SafetyReq {
        doc "The Safety System shall shut down the RF generator if any unsafe condition is detected.";
        attribute maxSafeTemp : TempC = 250.0;
    }

    requirement def CoolingReq {
        doc "The Cooling System shall maintain generator coolant temperature below threshold during full power operation.";
        attribute maxCoolantTemp : TempC = 40.0;
        attribute minFlowRate : FlowLpm = 20.0;
    }

    // ============================================================
    // Part Definitions — Leaf Components
    // ============================================================

    part def RFPowerGenerator {
        attribute maxOutputPower : PowerW = 50000;
        attribute operatingFrequency : FreqMHz = 27.12;
        attribute currentOutputPower : PowerW = 0;

        port rfOut : RFEnergyOutPort;
        port powerCmd : PowerCmdPort;
        port safetyShutdown : SafetyCmdPort;
        port coolantIn : CoolantFlowPort;
        port coolantOut : CoolantReturnPort;

        exhibit state def GeneratorState {
            state idle;
            state generating;
            state shutdown;

            transition idle to generating
                when powerCmd.commandedPower > 0
                and safetyShutdown.shutdownCmd == false;

            transition generating to idle
                when powerCmd.commandedPower == 0;

            transition idle to shutdown
                when safetyShutdown.shutdownCmd == true;

            transition generating to shutdown
                when safetyShutdown.shutdownCmd == true;

            transition shutdown to idle
                when safetyShutdown.shutdownCmd == false;
        }

        action def GenerateRF {
            in cmd : PowerW;
            out energy : RFEnergy;
            out actualPower : PowerW;
            private attribute effectivePower : PowerW;
            assign effectivePower = if cmd > maxOutputPower then maxOutputPower else cmd;
            assign actualPower = effectivePower;
        }
    }

    part def DielectricApplicator {
        attribute chamberVolume : Real = 0.5;
        attribute fieldUniformity : Percent = 95.0;
        attribute workpieceTemp : TempC = 25.0;

        port rfIn : RFEnergyInPort;
        port sensorAccess : TempReadingPort;

        attribute workpiece : Workpiece;

        action def ApplyField {
            in rfEnergy : RFEnergy;
            in material : Workpiece;
            in inputPower : PowerW;
            out heatedMaterial : Workpiece;
            out currentTemp : TempC;
            private attribute tempRise : TempC;
            assign tempRise = inputPower * 0.0001;
            assign currentTemp = workpieceTemp + tempRise;
            assign heatedMaterial = material;
        }
    }

    part def TemperatureSensor {
        attribute sensorType : String = "FiberOptic";
        attribute measurementRangeMin : TempC = 0.0;
        attribute measurementRangeMax : TempC = 400.0;
        attribute accuracy : TempC = 0.5;
        attribute sampleRateHz : Real = 10.0;

        port tempOut : TempReadingPort;

        action def MeasureTemp {
            in material : Workpiece;
            out temperature : TempC;
            private attribute rawReading : TempC;
            assign rawReading = 25.0;
            assign temperature = rawReading;
        }
    }

    part def HeatingController {
        attribute kp : Real = 2.0;
        attribute ki : Real = 0.5;
        attribute kd : Real = 0.1;
        attribute targetTemperature : TempC = 100.0;
        attribute currentTemperature : TempC = 25.0;
        attribute integralError : Real = 0.0;
        attribute previousError : TempC = 0.0;
        attribute computedPower : PowerW = 0;
        attribute holdTimer : TimeS = 0.0;
        attribute holdDuration : TimeS = 300.0;

        port sensorInput : TempReadingPort;
        port userCmd : UserCmdPort;
        port generatorCmd : PowerCmdPort;

        action def PIDCompute {
            in setpoint : TempC;
            in measured : TempC;
            in dt : TimeS;
            in p : Real;
            in i : Real;
            in d : Real;
            in prevError : TempC;
            in accumError : Real;
            out powerCmd : PowerW;
            out newError : TempC;
            out newAccumError : Real;

            private attribute error : TempC;
            private attribute derivative : Real;
            private attribute rawPower : PowerW;

            assign error = setpoint - measured;
            assign newAccumError = accumError + error * dt;
            assign derivative = (error - prevError) / dt;
            assign rawPower = p * error + i * newAccumError + d * derivative;
            assign powerCmd = if rawPower < 0 then 0 else if rawPower > 50000 then 50000 else rawPower;
            assign newError = error;
        }

        action def UpdateControl {
            in dt : TimeS;
            private attribute pidResult : PowerW;
            assign currentTemperature = sensorInput.measuredTemp;
            assign targetTemperature = userCmd.targetTemp;
            assign holdDuration = userCmd.holdTime;
            then PIDCompute {
                in setpoint = targetTemperature;
                in measured = currentTemperature;
                in dt = dt;
                in p = kp;
                in i = ki;
                in d = kd;
                in prevError = previousError;
                in accumError = integralError;
                out powerCmd = computedPower;
                out newError = previousError;
                out newAccumError = integralError;
            }
            assign generatorCmd.commandedPower = computedPower;
        }
    }

    part def CoolingSystem {
        attribute pumpFlowRate : FlowLpm = 25.0;
        attribute coolantType : String = "DeionizedWater";
        attribute radiatorFanSpeed : Percent = 80.0;
        attribute maxCoolantTemp : TempC = 40.0;

        port coolantSupply : CoolantFlowPort;
        port coolantReturn : CoolantReturnPort;

        exhibit state def CoolingState {
            state off;
            state running;

            transition off to running when true;
        }

        action def CirculateCoolant {
            in returnTemp : TempC;
            out supplyTemp : TempC;
            out flowRate : FlowLpm;
            private attribute deltaT : TempC;
            assign deltaT = returnTemp - maxCoolantTemp;
            assign supplyTemp = if returnTemp > maxCoolantTemp then returnTemp - 5.0 else returnTemp;
            assign flowRate = pumpFlowRate;
        }
    }

    part def SafetySystem {
        attribute doorClosed : Boolean = true;
        attribute emergencyStopPressed : Boolean = false;
        attribute maxSafeTemp : TempC = 250.0;
        attribute overTemp : Boolean = false;
        attribute faultCode : Integer = 0;
        attribute systemSafe : Boolean = true;

        port sensorInput : TempReadingPort;
        port shutdownOutput : SafetyCmdPort;
        port statusOutput : SafetyStatusPort;

        action def MonitorSafety {
            in doorStatus : Boolean;
            in estopStatus : Boolean;
            in currentTemp : TempC;
            out safe : Boolean;
            out code : Integer;

            private attribute tempExceeded : Boolean;
            assign tempExceeded = currentTemp > maxSafeTemp;

            assign safe = doorStatus and not estopStatus and not tempExceeded;
            assign code = if not doorStatus then 1 else if estopStatus then 2 else if tempExceeded then 3 else 0;
        }

        action def EvaluateSafety {
            private attribute monitorResult : Boolean;
            private attribute detectedCode : Integer;
            then MonitorSafety {
                in doorStatus = doorClosed;
                in estopStatus = emergencyStopPressed;
                in currentTemp = sensorInput.measuredTemp;
                out safe = systemSafe;
                out code = faultCode;
            }
            assign shutdownOutput.shutdownCmd = not systemSafe;
            assign statusOutput.systemSafe = systemSafe;
            assign statusOutput.faultId = faultCode;
        }
    }

    part def UserInterface {
        attribute displayTargetTemp : TempC = 100.0;
        attribute displayCurrentTemp : TempC = 25.0;
        attribute displayStatus : String = "Standby";

        port userCmd : UserCmdPort;

        action def AcceptUserInput {
            in desiredTemp : TempC;
            in holdTime : TimeS;
            in startCmd : Boolean;
            in stopCmd : Boolean;
            out target : TempC;
            out duration : TimeS;
            out start : Boolean;
            out stop : Boolean;
            assign target = desiredTemp;
            assign duration = holdTime;
            assign start = startCmd;
            assign stop = stopCmd;
        }
    }

    // ============================================================
    // System Part Definition
    // ============================================================

    part def IndustrialDielectricHeatingSystem {
        satisfy UniformHeatingReq;
        satisfy PowerGenerationReq;
        satisfy TempControlReq;
        satisfy SafetyReq;
        satisfy CoolingReq;

        attribute systemName : String = "IndustrialDielectricHeater";
        attribute ratedPower : PowerW = 50000;
        attribute operatingFrequency : FreqMHz = 27.12;

        part rfGenerator : RFPowerGenerator;
        part applicator : DielectricApplicator;
        part tempSensor : TemperatureSensor;
        part controller : HeatingController;
        part cooling : CoolingSystem;
        part safety : SafetySystem;
        part ui : UserInterface;

        // ---- Connections ----

        // RF energy from generator to applicator
        connect rfGenerator.rfOut to applicator.rfIn;

        // Temperature sensor feeds controller and safety system
        connect tempSensor.tempOut to controller.sensorInput;
        connect tempSensor.tempOut to safety.sensorInput;

        // Controller commands generator power
        connect controller.generatorCmd to rfGenerator.powerCmd;

        // Safety system can shut down generator
        connect safety.shutdownOutput to rfGenerator.safetyShutdown;

        // User interface commands controller
        connect ui.userCmd to controller.userCmd;

        // Cooling loop
        connect cooling.coolantSupply to rfGenerator.coolantIn;
        connect rfGenerator.coolantOut to cooling.coolantReturn;

        // ---- System Lifecycle State Machine ----

        exhibit state def SystemLifecycle {

            attribute currentMode : String = "Standby";
            attribute modeTimer : TimeS = 0.0;
            attribute preheatThreshold : TempC = 50.0;
            attribute coolingThreshold : TempC = 50.0;

            state standby {
                entry assign currentMode = "Standby";
                assign controller.computedPower = 0;
            }

            state preheating {
                entry assign currentMode = "Preheating";
            }

            state activeHeating {
                entry assign currentMode = "ActiveHeating";
            }

            state holding {
                entry assign currentMode = "Holding";
                assign modeTimer = 0.0;
            }

            state cooling {
                entry assign currentMode = "Cooling";
                assign controller.computedPower = 0;
            }

            state fault {
                entry assign currentMode = "Fault";
                assign controller.computedPower = 0;
            }

            // Normal transitions
            transition standby to preheating
                when ui.userCmd.start == true
                and safety.statusOutput.systemSafe == true;

            transition preheating to activeHeating
                when controller.currentTemperature >= preheatThreshold;

            transition activeHeating to holding
                when controller.currentTemperature >= controller.targetTemperature - 2.0;

            transition holding to cooling
                when controller.holdTimer >= controller.holdDuration;

            transition cooling to standby
                when controller.currentTemperature <= coolingThreshold;

            // Safety fault transitions
            transition standby to fault
                when safety.statusOutput.systemSafe == false;

            transition preheating to fault
                when safety.statusOutput.systemSafe == false;

            transition activeHeating to fault
                when safety.statusOutput.systemSafe == false;

            transition holding to fault
                when safety.statusOutput.systemSafe == false;

            transition cooling to fault
                when safety.statusOutput.systemSafe == false;

            // Fault recovery
            transition fault to standby
                when safety.statusOutput.systemSafe == true
                and ui.userCmd.stop == true;
        }
    }

    // ============================================================
    // Requirement Verification
    // ============================================================

    requirement UniformHeatingVerification :> UniformHeatingReq {
        subject system : IndustrialDielectricHeatingSystem;
        objective {
            doc "Verify that the system achieves uniform heating at 27.12 MHz with temperature gradient below 5 degC.";
        }
    }

    requirement SafetyVerification :> SafetyReq {
        subject system : IndustrialDielectricHeatingSystem;
        objective {
            doc "Verify that the safety system shuts down RF power when door is open, e-stop is pressed, or temperature exceeds 250 degC.";
        }
    }

    requirement CoolingVerification :> CoolingReq {
        subject system : IndustrialDielectricHeatingSystem;
        objective {
            doc "Verify coolant supply temperature remains below 40 degC at full 50 kW power with flow rate of at least 20 L/min.";
        }
    }

}
