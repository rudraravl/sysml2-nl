package HydristorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HydraulicPressureValue :> PressureValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def DisplacementValue :> VolumeValue;
    attribute def ControlSignalValue :> Real;
    
    item def HydraulicFluid {
        attribute viscosity : Real;
        attribute density : DensityValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    port def HydraulicPort {
        attribute pressure : HydraulicPressureValue;
        attribute flowRate : FlowRateValue;
        in item fluid : HydraulicFluid;
    }
    
    port def ControlPort {
        in attribute signal : ControlSignalValue;
    }
    
    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute speed : AngularVelocityValue;
    }
    
    part def Hydristor {
        doc /* A Hydristor is a variable-displacement hydraulic motor/pump that 
               converts hydraulic energy to mechanical energy or vice versa. 
               Its displacement can be continuously adjusted to control output 
               torque and speed. */
        
        port hydraulicIn : HydraulicPort;
        port hydraulicOut : HydraulicPort;
        port mechanicalShaft : MechanicalPort;
        port displacementControl : ControlPort;
        
        attribute currentDisplacement : DisplacementValue;
        attribute maxDisplacement : DisplacementValue;
        attribute minDisplacement : DisplacementValue;
        attribute efficiency : Real;
        
        action def AdjustDisplacement {
            in controlSignal : ControlSignalValue;
            in currentDisp : DisplacementValue;
            in maxDisp : DisplacementValue;
            in minDisp : DisplacementValue;
            out newDisplacement : DisplacementValue;
        }
        
        action def ConvertHydraulicToMechanical {
            in pressure : HydraulicPressureValue;
            in flowRate : FlowRateValue;
            in displacement : DisplacementValue;
            in eff : Real;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
            out outPressure : HydraulicPressureValue;
            out outFlowRate : FlowRateValue;
        }
        
        perform action operateHydristor {
            first start;
            then merge continuousOperation;
            
            action adjustDisp : AdjustDisplacement {
                in controlSignal = displacementControl.signal;
                in currentDisp = currentDisplacement;
                in maxDisp = maxDisplacement;
                in minDisp = minDisplacement;
                out newDisplacement;
            }
            
            then action updateDisplacement {
                assign currentDisplacement := adjustDisp.newDisplacement;
            }
            
            then action convert : ConvertHydraulicToMechanical {
                in pressure = hydraulicIn.pressure;
                in flowRate = hydraulicIn.flowRate;
                in displacement = currentDisplacement;
                in eff = efficiency;
                out torque;
                out speed;
                out outPressure;
                out outFlowRate;
            }
            
            then action updateOutputs {
                assign mechanicalShaft.torque := convert.torque;
                assign mechanicalShaft.speed := convert.speed;
                assign hydraulicOut.pressure := convert.outPressure;
                assign hydraulicOut.flowRate := convert.outFlowRate;
            }
            
            then continuousOperation;
        }
    }
    
    part def HydraulicPump {
        port mechanicalInput : MechanicalPort;
        port hydraulicOutput : HydraulicPort;
        
        attribute displacement : DisplacementValue;
        attribute efficiency : Real;
        
        action generatePressure {
            in torque : TorqueValue;
            in speed : AngularVelocityValue;
            out pressure : HydraulicPressureValue;
            out flowRate : FlowRateValue;
        }
    }
    
    part def HydraulicReservoir {
        port supply : HydraulicPort;
        port returnPort : HydraulicPort;
        
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        item storedFluid : HydraulicFluid;
    }
    
    part def PressureSensor {
        port sensing : HydraulicPort;
        out attribute measuredPressure : HydraulicPressureValue;
        
        action measure {
            assign measuredPressure := sensing.pressure;
        }
    }
    
    part def SpeedSensor {
        port sensing : MechanicalPort;
        out attribute measuredSpeed : AngularVelocityValue;
        
        action measure {
            assign measuredSpeed := sensing.speed;
        }
    }
    
    part def DisplacementController {
        in attribute targetSpeed : AngularVelocityValue;
        in attribute measuredSpeed : AngularVelocityValue;
        in attribute measuredPressure : HydraulicPressureValue;
        out attribute controlSignal : ControlSignalValue;
        
        action def ComputeControl {
            in target : AngularVelocityValue;
            in actual : AngularVelocityValue;
            in pressure : HydraulicPressureValue;
            out control : ControlSignalValue;
        }
        
        perform action controlLoop {
            loop {
                action compute : ComputeControl {
                    in target = targetSpeed;
                    in actual = measuredSpeed;
                    in pressure = measuredPressure;
                    out control;
                }
                then assign controlSignal := compute.control;
            }
        }
    }
    
    part def MechanicalLoad {
        port input : MechanicalPort;
        
        attribute inertia : Real;
        attribute loadTorque : TorqueValue;
        
        action applyLoad {
            in inputTorque : TorqueValue;
            in inputSpeed : AngularVelocityValue;
            out netTorque : TorqueValue;
        }
    }
    
    part def PrimeDriver {
        port output : MechanicalPort;
        
        attribute constantTorque : TorqueValue;
        attribute constantSpeed : AngularVelocityValue;
        
        action drive {
            assign output.torque := constantTorque;
            assign output.speed := constantSpeed;
        }
    }
    
    part def HydristorDriveSystem {
        doc /* A Hydristor-based hydraulic drive system that provides continuously 
               variable speed control of a mechanical load. The system uses a fixed-
               displacement hydraulic pump driven by a prime mover to generate hydraulic 
               pressure. This pressure drives a variable-displacement Hydristor, which 
               converts the hydraulic energy into mechanical rotation. By continuously 
               adjusting the Hydristor's displacement based on feedback from pressure 
               and speed sensors, the system precisely controls the output speed and 
               torque delivered to the mechanical load, enabling smooth and efficient 
               power transmission across a wide operating range. */
        
        part primeDriver : PrimeDriver {
            attribute constantTorque = 100.0;
            attribute constantSpeed = 1800.0;
        }
        
        part pump : HydraulicPump {
            attribute displacement = 0.05;
            attribute efficiency = 0.92;
        }
        
        part reservoir : HydraulicReservoir {
            attribute capacity = 200.0;
            attribute currentLevel = 180.0;
        }
        
        part hydristor : Hydristor {
            attribute maxDisplacement = 0.08;
            attribute minDisplacement = 0.01;
            attribute currentDisplacement = 0.04;
            attribute efficiency = 0.90;
        }
        
        part pressureSensor : PressureSensor;
        part speedSensor : SpeedSensor;
        
        part controller : DisplacementController {
            attribute targetSpeed = 1200.0;
        }
        
        part load : MechanicalLoad {
            attribute inertia = 5.0;
            attribute loadTorque = 50.0;
        }
        
        connect primeDriver.output to pump.mechanicalInput;
        connect pump.hydraulicOutput to hydristor.hydraulicIn;
        connect hydristor.hydraulicOut to reservoir.returnPort;
        connect reservoir.supply to pump.hydraulicOutput;
        connect hydristor.mechanicalShaft to load.input;
        connect hydristor.hydraulicIn to pressureSensor.sensing;
        connect hydristor.mechanicalShaft to speedSensor.sensing;
        
        bind pressureSensor.measuredPressure = controller.measuredPressure;
        bind speedSensor.measuredSpeed = controller.measuredSpeed;
        bind controller.controlSignal = hydristor.displacementControl.signal;
        
        perform action systemOperation {
            first start;
            
            action initialize {
                assign reservoir.currentLevel := reservoir.capacity * 0.9;
                assign controller.targetSpeed := 1200.0;
                assign hydristor.currentDisplacement := hydristor.maxDisplacement * 0.5;
            }
            
            then action {
                perform primeDriver.drive;
                perform pump.generatePressure;
                perform hydristor.operateHydristor;
                perform controller.controlLoop;
                perform pressureSensor.measure;
                perform speedSensor.measure;
                perform load.applyLoad;
            }
        }
    }
    
    requirement def VariableSpeedControlRequirement {
        doc /* The Hydristor system shall provide continuously variable speed 
               control of the mechanical load by adjusting the Hydristor displacement 
               in response to control inputs. */
        
        subject system : HydristorDriveSystem;
        
        require constraint {
            system.hydristor.currentDisplacement >= system.hydristor.minDisplacement and
            system.hydristor.currentDisplacement <= system.hydristor.maxDisplacement
        }
    }
    
    requirement def EnergyConversionRequirement {
        doc /* The Hydristor shall efficiently convert hydraulic energy from the 
               pump into mechanical rotational energy delivered to the load. */
        
        attribute minEfficiency : Real;
    }
    
    requirement def PressureRegulationRequirement {
        doc /* The system shall maintain hydraulic pressure within safe operating 
               limits during all operating conditions. */
        
        attribute maxPressure : HydraulicPressureValue;
        attribute minPressure : HydraulicPressureValue;
    }
    
    part hydristorDriveSystem : HydristorDriveSystem {
        satisfy reqVSC : VariableSpeedControlRequirement by hydristor;
        
        satisfy reqEC : EnergyConversionRequirement {
            attribute minEfficiency = 0.85;
        }
        
        satisfy reqPR : PressureRegulationRequirement {
            attribute maxPressure = 350.0;
            attribute minPressure = 50.0;
        }
    }
    
    action def RegulateHydraulicDrive {
        doc /* Primary system function: Regulate the speed and torque of a mechanical 
               load by continuously adjusting the displacement of a Hydristor based on 
               hydraulic pressure and rotational speed feedback, enabling precise and 
               efficient variable-speed power transmission. */
        
        in targetSpeed : AngularVelocityValue;
        in supplyPressure : HydraulicPressureValue;
        in supplyFlow : FlowRateValue;
        out actualSpeed : AngularVelocityValue;
        out outputTorque : TorqueValue;
        
        action senseConditions {
            out sensedPressure : HydraulicPressureValue;
            out sensedSpeed : AngularVelocityValue;
        }
        
        then action computeControl {
            in target : AngularVelocityValue = targetSpeed;
            in actualSpeed : AngularVelocityValue;
            in pressure : HydraulicPressureValue;
            out controlSignal : ControlSignalValue;
        }
        
        then action adjustHydristor {
            in control : ControlSignalValue;
            out displacement : DisplacementValue;
        }
        
        then action convertEnergy {
            in displacement : DisplacementValue;
            in pressure : HydraulicPressureValue;
            in flowRate : FlowRateValue;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
        }
        
        then assign actualSpeed := convertEnergy.speed;
        then assign outputTorque := convertEnergy.torque;
    }
}
