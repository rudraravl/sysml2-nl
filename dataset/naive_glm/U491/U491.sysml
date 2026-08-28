package CycloidalDriveSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    value def AngularVelocityValue :> Real { unit = 'rad/s'; }
    value def RotationalSpeedValue :> Real { unit = 'rev/min'; }
    value def TorqueValue :> Real { unit = 'N*m'; }
    value def TemperatureValue :> Real { unit = 'degC'; }
    value def PowerValue :> Real { unit = 'W'; }
    value def LengthValue :> Real { unit = 'mm'; }
    value def MassValue :> Real { unit = 'kg'; }
    value def PressureValue :> Real { unit = 'Pa'; }
    value def VolumetricFlowRateValue :> Real { unit = 'L/min'; }
    value def ReductionRatioValue :> Real { unit = '1'; }
    value def EfficiencyValue :> Real { unit = '%' [min = 0, max = 100]; }
    value def BooleanStatus :> Boolean;
    
    // ===== Item Types =====
    item def Lubricant {
        attribute viscosity : Real { unit = 'mm^2/s'; }
        attribute flashPoint : TemperatureValue;
        attribute grade : String;
    }
    
    item def MechanicalPower {
        port in inputTorque : TorqueValue;
        port in inputSpeed : RotationalSpeedValue;
        port out outputTorque : TorqueValue;
        port out outputSpeed : RotationalSpeedValue;
    }
    
    // ===== Interfaces =====
    port def RotationalInterface {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute direction : String;
    }
    
    port def ThermalInterface {
        attribute temperature : TemperatureValue;
    }
    
    port def LubricationInterface {
        attribute flowRate : VolumetricFlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def ControlInterface {
        attribute command : String;
        attribute status : String;
    }
    
    port def SensorInterface {
        attribute measuredValue : Real;
        attribute sensorType : String;
    }
    
    // ===== Enumerations =====
    enum DriveState { idle, running, overload }
    enum Command { start, stop, reset }
    
    // ===== Requirements =====
    requirement def SpeedReductionRequirement {
        doc /* The drive shall reduce input speed by the specified ratio. */
        attribute reductionRatio : ReductionRatioValue = 75;
        requirement inputSpeed : RotationalSpeedValue;
        requirement outputSpeed : RotationalSpeedValue;
        require constraint { outputSpeed == inputSpeed / reductionRatio }
    }
    
    requirement def TorqueMultiplicationRequirement {
        doc /* The drive shall multiply input torque proportionally to the reduction ratio. */
        attribute efficiency : EfficiencyValue = 90;
        requirement inputTorque : TorqueValue;
        requirement outputTorque : TorqueValue;
        require constraint { outputTorque == inputTorque * reductionRatio * (efficiency / 100) }
    }
    
    requirement def ThermalProtectionRequirement {
        doc /* The drive shall shut down if operating temperature exceeds safe limit. */
        attribute maxOperatingTemp : TemperatureValue = 85;
        require constraint { if operatingTemp > maxOperatingTemp then state == DriveState::overload }
    }
    
    requirement def OverloadProtectionRequirement {
        doc /* The drive shall enter overload state when torque exceeds rated capacity. */
        attribute maxTorque : TorqueValue = 500;
        require constraint { if measuredTorque > maxTorque then state == DriveState::overload }
    }
    
    requirement def LubricationRequirement {
        doc /* The drive shall maintain oil flow to all moving components. */
        attribute minFlowRate : VolumetricFlowRateValue = 0.5;
        require constraint { oilFlowRate >= minFlowRate }
    }
    
    requirement def PrecisionRequirement {
        doc /* The drive shall maintain high positional accuracy with minimal backlash. */
        attribute maxBacklash : LengthValue = 1.0;
        attribute maxPositionError : LengthValue = 0.5;
    }
    
    // ===== Part Definitions =====
    part def InputShaft {
        attribute length : LengthValue = 120;
        attribute diameter : LengthValue = 20;
        attribute material : String = "High-Strength Steel";
        port in mechanicalInput : RotationalInterface;
        port out eccentricDrive : RotationalInterface;
    }
    
    part def EccentricDisc {
        attribute eccentricity : LengthValue = 1.5;
        attribute outerDiameter : LengthValue = 80;
        attribute material : String = "Hardened Alloy Steel";
        port in shaftDrive : RotationalInterface;
        port out cycloidalDrive : RotationalInterface;
    }
    
    part def CycloidalGear {
        attribute toothCount : Integer = 40;
        attribute pitchDiameter : LengthValue = 100;
        attribute thickness : LengthValue = 15;
        attribute material : String = "Case-Hardened Steel";
        attribute backlash : LengthValue = 0.8;
        port in orbitalDrive : RotationalInterface;
        port out reducedOutput : RotationalInterface;
    }
    
    part def Housing {
        attribute outerDiameter : LengthValue = 150;
        attribute innerDiameter : LengthValue = 120;
        attribute pinCount : Integer = 41;
        attribute pinDiameter : LengthValue = 5;
        attribute material : String = "Cast Iron";
        port in thermalOutput : ThermalInterface;
    }
    
    part def OutputShaft {
        attribute length : LengthValue = 100;
        attribute diameter : LengthValue = 30;
        attribute material : String = "High-Strength Steel";
        port in gearOutput : RotationalInterface;
        port out mechanicalOutput : RotationalInterface;
    }
    
    part def BearingAssembly {
        attribute type : String;
        attribute boreDiameter : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute loadRating : TorqueValue;
        attribute location : String;
    }
    
    part def TemperatureSensor {
        attribute range : TemperatureValue;
        attribute accuracy : TemperatureValue;
        port out tempReading : SensorInterface;
    }
    
    part def TorqueSensor {
        attribute range : TorqueValue;
        attribute accuracy : TorqueValue;
        port out torqueReading : SensorInterface;
    }
    
    part def OilPump {
        attribute ratedFlow : VolumetricFlowRateValue = 2.0;
        attribute ratedPressure : PressureValue = 200000;
        port out oilSupply : LubricationInterface;
    }
    
    part def OilReservoir {
        attribute capacity : Real { unit = 'L' } = 1.5;
        attribute oilType : Lubricant;
        port out oilOutput : LubricationInterface;
    }
    
    part def LubricationSystem {
        part pump : OilPump;
        part reservoir : OilReservoir;
        port out lubricationSupply : LubricationInterface;
        connection pump.oilSupply to lubricationSupply;
        connection reservoir.oilOutput to pump.oilSupply;
    }
    
    part def DriveController {
        attribute state : DriveState = DriveState::idle;
        attribute command : Command;
        attribute maxTemp : TemperatureValue = 85;
        attribute maxTorque : TorqueValue = 500;
        port in controlInput : ControlInterface;
        port in tempFeedback : SensorInterface;
        port in torqueFeedback : SensorInterface;
        port out controlOutput : ControlInterface;
        
        state machine ControllerStateMachine {
            state idle {
                entry action { state = DriveState::idle; }
                transition running on controlInput.command == "start" {
                    guard tempFeedback.measuredValue < maxTemp
                        and torqueFeedback.measuredValue < maxTorque;
                }
            }
            state running {
                entry action { state = DriveState::running; }
                transition overload on tempFeedback.measuredValue > maxTemp
                    or torqueFeedback.measuredValue > maxTorque;
                transition idle on controlInput.command == "stop";
            }
            state overload {
                entry action { state = DriveState::overload; }
                transition idle on controlInput.command == "reset"
                    and tempFeedback.measuredValue < maxTemp
                    and torqueFeedback.measuredValue < maxTorque;
            }
        }
    }
    
    // ===== Main System =====
    part def CycloidalDrive {
        attribute reductionRatio : ReductionRatioValue = 75;
        attribute efficiency : EfficiencyValue = 90;
        attribute maxInputSpeed : RotationalSpeedValue = 3000;
        attribute maxInputTorque : TorqueValue = 6.7;
        attribute maxOutputTorque : TorqueValue = 500;
        attribute maxOperatingTemp : TemperatureValue = 85;
        attribute packageSize : LengthValue = 150;
        attribute mass : MassValue = 8.5;
        
        port in motorInput : RotationalInterface;
        port out driveOutput : RotationalInterface;
        port in controlCommand : ControlInterface;
        port out statusFeedback : ControlInterface;
        
        part inputShaft : InputShaft;
        part eccentricDisc : EccentricDisc;
        part cycloidalGear : CycloidalGear;
        part housing : Housing;
        part outputShaft : OutputShaft;
        part inputBearing : BearingAssembly {
            attribute type = "Deep Groove Ball Bearing";
            attribute boreDiameter = 20;
            attribute outerDiameter = 47;
            attribute loadRating = 12000;
            attribute location = "Input Side";
        }
        part outputBearing : BearingAssembly {
            attribute type = "Tapered Roller Bearing";
            attribute boreDiameter = 30;
            attribute outerDiameter = 72;
            attribute loadRating = 25000;
            attribute location = "Output Side";
        }
        part tempSensor : TemperatureSensor {
            attribute range = 150;
            attribute accuracy = 0.5;
        }
        part torqueSensor : TorqueSensor {
            attribute range = 600;
            attribute accuracy = 2.0;
        }
        part lubricationSystem : LubricationSystem;
        part controller : DriveController;
        
        // Connections - mechanical power flow
        connection motorInput to inputShaft.mechanicalInput;
        connection inputShaft.eccentricDrive to eccentricDisc.shaftDrive;
        connection eccentricDisc.cycloidalDrive to cycloidalGear.orbitalDrive;
        connection cycloidalGear.reducedOutput to outputShaft.gearOutput;
        connection outputShaft.mechanicalOutput to driveOutput;
        
        // Bearing connections
        connection inputBearing supports inputShaft;
        connection outputBearing supports outputShaft;
        
        // Sensor connections
        connection tempSensor.tempReading to controller.tempFeedback;
        connection torqueSensor.torqueReading to controller.torqueFeedback;
        
        // Control connections
        connection controlCommand to controller.controlInput;
        connection controller.controlOutput to statusFeedback;
        
        // Lubrication connections
        connection lubricationSystem.lubricationSupply to housing.thermalOutput;
        
        // Requirements satisfaction
        satisfy SpeedReductionRequirement {
            reductionRatio = reductionRatio;
            inputSpeed = motorInput.speed;
            outputSpeed = driveOutput.speed;
        }
        satisfy TorqueMultiplicationRequirement {
            efficiency = efficiency;
            inputTorque = motorInput.torque;
            outputTorque = driveOutput.torque;
        }
        satisfy ThermalProtectionRequirement {
            maxOperatingTemp = maxOperatingTemp;
        }
        satisfy OverloadProtectionRequirement {
            maxTorque = maxOutputTorque;
        }
        satisfy LubricationRequirement {
            minFlowRate = 0.5;
        }
        satisfy PrecisionRequirement {
            maxBacklash = cycloidalGear.backlash;
            maxPositionError = 0.5;
        }
        
        // Operational action
        action def OperateDrive {
            input inputCommand : Command;
            input currentTemp : TemperatureValue;
            input currentTorque : TorqueValue;
            output driveState : DriveState;
            
            if inputCommand == Command::start and currentTemp < 85 and currentTorque < 500 then {
                driveState = DriveState::running;
            } else if currentTemp > 85 or currentTorque > 500 then {
                driveState = DriveState::overload;
            } else {
                driveState = DriveState::idle;
            }
        }
    }
}
