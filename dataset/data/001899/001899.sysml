package WindmillSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def WindSpeed :> ISQ::VelocityValue;
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
    attribute def ElectricalPower :> ISQ::PowerValue;
    attribute def MechanicalTorque :> ISQ::TorqueValue;
    attribute def BladeAngle :> ISQ::AngleValue;
    attribute def Efficiency :> Real;

    item def Wind {
        attribute speed : WindSpeed;
        attribute direction : Real;
        attribute density : ISQ::MassDensityValue;
    }

    item def ElectricalGrid {
        attribute voltage : ISQ::VoltageValue;
        attribute frequency : ISQ::FrequencyValue;
        port gridConnection {
            in power : ElectricalPower;
        }
    }

    port def WindInputPort {
        in windSpeed : WindSpeed;
        in windDirection : Real;
    }

    port def MechanicalPort {
        out torque : MechanicalTorque;
        out rotSpeed : RotationalSpeed;
    }

    port def ElectricalPort {
        out power : ElectricalPower;
        out voltage : ISQ::VoltageValue;
        out current : ISQ::ElectricCurrentValue;
    }

    port def ControlPort {
        in sensorData : Real;
        out commandSignal : Real;
    }

    part def Blade {
        attribute length : ISQ::LengthValue;
        attribute pitchAngle : BladeAngle;
        attribute mass : ISQ::MassValue;
        attribute surfaceArea : ISQ::AreaValue;
    }

    part def RotorHub {
        attribute diameter : ISQ::LengthValue;
        attribute rotationalSpeed : RotationalSpeed;
        attribute sweptArea : ISQ::AreaValue;
        
        part blades : Blade[3] {
            attribute :>> length = 45.0 [m];
            attribute :>> mass = 7000.0 [kg];
        }

        port windInput : WindInputPort;
        port mechanicalOutput : MechanicalPort;

        assert constraint sweptAreaCalculation {
            sweptArea == 3.14159 * (blades.length ** 2)
        }
    }

    part def Gearbox {
        attribute gearRatio : Real;
        attribute efficiency : Efficiency;
        
        port mechanicalInput : MechanicalPort;
        port mechanicalOutput : MechanicalPort;

        assert constraint speedConversion {
            mechanicalOutput.rotSpeed == mechanicalInput.rotSpeed * gearRatio
        }

        assert constraint torqueConversion {
            mechanicalOutput.torque == (mechanicalInput.torque / gearRatio) * efficiency
        }
    }

    part def Generator {
        attribute ratedPower : ElectricalPower;
        attribute efficiency : Efficiency;
        attribute outputVoltage : ISQ::VoltageValue;
        
        port mechanicalInput : MechanicalPort;
        port electricalOutput : ElectricalPort;

        assert constraint powerConversion {
            electricalOutput.power == (mechanicalInput.torque * mechanicalInput.rotSpeed) * efficiency
        }

        assert constraint currentCalculation {
            electricalOutput.current == electricalOutput.power / electricalOutput.voltage
        }
    }

    part def YawSystem {
        attribute currentYawAngle : BladeAngle;
        attribute targetYawAngle : BladeAngle;
        
        port windSensor : WindInputPort;
        port yawControl {
            out yawAngle : BladeAngle;
        }
    }

    part def PitchSystem {
        attribute currentPitchAngle : BladeAngle;
        attribute targetPitchAngle : BladeAngle;
        
        port speedSensor {
            in rotSpeed : RotationalSpeed;
        }
        port pitchControl {
            out pitchAngle : BladeAngle;
        }
    }

    part def BrakeSystem {
        attribute isEngaged : Boolean;
        attribute brakingTorque : MechanicalTorque;
        
        port brakeControl {
            in emergencyStop : Boolean;
        }
    }

    part def PowerConverter {
        attribute inputVoltage : ISQ::VoltageValue;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute outputFrequency : ISQ::FrequencyValue;
        attribute efficiency : Efficiency;
        
        port electricalInput : ElectricalPort;
        port gridOutput {
            out power : ElectricalPower;
            out voltage : ISQ::VoltageValue;
            out frequency : ISQ::FrequencyValue;
        }

        assert constraint powerEfficiency {
            gridOutput.power == electricalInput.power * efficiency
        }
    }

    part def ControlSystem {
        attribute cutInSpeed : WindSpeed;
        attribute ratedSpeed : WindSpeed;
        attribute cutOutSpeed : WindSpeed;
        attribute currentWindSpeed : WindSpeed;
        attribute currentRotorSpeed : RotationalSpeed;
        
        port windMonitor : WindInputPort;
        port rotorMonitor {
            in rotSpeed : RotationalSpeed;
        }
        port yawCommand {
            out targetYaw : BladeAngle;
        }
        port pitchCommand {
            out targetPitch : BladeAngle;
        }
        port brakeCommand {
            out engage : Boolean;
        }
    }

    part def Tower {
        attribute height : ISQ::LengthValue;
        attribute baseDiameter : ISQ::LengthValue;
        attribute topDiameter : ISQ::LengthValue;
        attribute mass : ISQ::MassValue;
    }

    part def Nacelle {
        attribute mass : ISQ::MassValue;
        attribute yawAngle : BladeAngle;
        
        part gearbox : Gearbox {
            attribute :>> gearRatio = 95.0;
            attribute :>> efficiency = 0.94;
        }
        
        part generator : Generator {
            attribute :>> ratedPower = 2500000.0 [W];
            attribute :>> efficiency = 0.96;
            attribute :>> outputVoltage = 690.0 [V];
        }
        
        part yawSystem : YawSystem;
        part pitchSystem : PitchSystem;
        part brakeSystem : BrakeSystem;
    }

    action def MonitorWindConditions {
        in wind : Wind;
        out windSpeed : WindSpeed;
        out windDirection : Real;
    }

    action def AdjustYaw {
        in currentYaw : BladeAngle;
        in windDirection : Real;
        out targetYaw : BladeAngle;
    }

    action def AdjustPitch {
        in currentPitch : BladeAngle;
        in rotorSpeed : RotationalSpeed;
        in targetSpeed : RotationalSpeed;
        out targetPitch : BladeAngle;
    }

    action def ConvertWindToMechanical {
        in windSpeed : WindSpeed;
        in bladeArea : ISQ::AreaValue;
        out mechanicalPower : ElectricalPower;
    }

    action def ConvertMechanicalToElectrical {
        in mechanicalTorque : MechanicalTorque;
        in rotSpeed : RotationalSpeed;
        out electricalPower : ElectricalPower;
    }

    action def DeliverToGrid {
        in generatedPower : ElectricalPower;
        out gridPower : ElectricalPower;
    }

    action def EngageBrake {
        out brakeEngaged : Boolean;
    }

    action def ReleaseBrake {
        out brakeReleased : Boolean;
    }

    action def GenerateElectricity {
        first start;
        then merge continueOperation;
        
        then action monitorWind : MonitorWindConditions {
            in wind : Wind;
            out windSpeed : WindSpeed;
            out windDirection : Real;
        }
        
        then decide;
            if monitorWind.windSpeed >= 3.5 && monitorWind.windSpeed < 25.0 then normalOperation;
            if monitorWind.windSpeed < 3.5 then stopOperation;
            if monitorWind.windSpeed >= 25.0 then emergencyStop;
        
        action normalOperation {
            first action adjustYaw : AdjustYaw {
                in windDirection = monitorWind.windDirection;
                out targetYaw : BladeAngle;
            }
            
            then action adjustPitch : AdjustPitch {
                out targetPitch : BladeAngle;
            }
            
            then action convertWind : ConvertWindToMechanical {
                in windSpeed = monitorWind.windSpeed;
                out mechanicalPower : ElectricalPower;
            }
            
            then action convertMechanical : ConvertMechanicalToElectrical {
                in mechanicalTorque : MechanicalTorque;
                out electricalPower : ElectricalPower;
            }
            
            then action deliverPower : DeliverToGrid {
                in generatedPower = convertMechanical.electricalPower;
                out gridPower : ElectricalPower;
            }
        }
        then continueOperation;
        
        action stopOperation;
        then done;
        
        action emergencyStop {
            action engageBrake : EngageBrake;
        }
        then done;
    }

    part def Windmill {
        attribute totalMass : ISQ::MassValue;
        attribute ratedPower : ElectricalPower;
        attribute cutInWindSpeed : WindSpeed;
        attribute ratedWindSpeed : WindSpeed;
        attribute cutOutWindSpeed : WindSpeed;
        attribute hubHeight : ISQ::LengthValue;
        attribute rotorDiameter : ISQ::LengthValue;
        
        part tower : Tower {
            attribute :>> height = 85.0 [m];
            attribute :>> baseDiameter = 4.5 [m];
            attribute :>> topDiameter = 2.5 [m];
            attribute :>> mass = 180000.0 [kg];
        }
        
        part nacelle : Nacelle {
            attribute :>> mass = 65000.0 [kg];
        }
        
        part rotor : RotorHub {
            attribute :>> diameter = 90.0 [m];
            attribute :>> sweptArea = 6362.0 [m^2];
        }
        
        part controlSystem : ControlSystem {
            attribute :>> cutInSpeed = 3.5 [m/s];
            attribute :>> ratedSpeed = 12.0 [m/s];
            attribute :>> cutOutSpeed = 25.0 [m/s];
        }
        
        part powerConverter : PowerConverter {
            attribute :>> outputVoltage = 20000.0 [V];
            attribute :>> outputFrequency = 50.0 [Hz];
            attribute :>> efficiency = 0.98;
        }
        
        perform action generateElectricity : GenerateElectricity;
        
        connection rotorToGearbox connect rotor.mechanicalOutput to nacelle.gearbox.mechanicalInput;
        connection gearboxToGenerator connect nacelle.gearbox.mechanicalOutput to nacelle.generator.mechanicalInput;
        connection generatorToConverter connect nacelle.generator.electricalOutput to powerConverter.electricalInput;
        connection windToRotor connect rotor.windInput to controlSystem.windMonitor;
        connection yawControl connect controlSystem.yawCommand to nacelle.yawSystem.yawControl;
        connection pitchControl connect controlSystem.pitchCommand to nacelle.pitchSystem.pitchControl;
        connection brakeControl connect controlSystem.brakeCommand to nacelle.brakeSystem.brakeControl;
        
        assert constraint totalMassConstraint {
            totalMass == tower.mass + nacelle.mass + (rotor.blades.mass * 3)
        }
        
        assert constraint operatingRange {
            cutInWindSpeed == 3.5 [m/s] &&
            ratedWindSpeed == 12.0 [m/s] &&
            cutOutWindSpeed == 25.0 [m/s]
        }
        
        assert constraint hubHeightConstraint {
            hubHeight == tower.height + nacelle.mass / 10000.0 [m]
        }
    }

    requirement <'REQ-WM-001'> primaryFunction {
        doc /* The windmill system shall convert kinetic energy from wind 
             * into electrical energy and deliver it to the electrical grid.
             */
        subject windmill : Windmill;
    }

    requirement <'REQ-WM-002'> powerGeneration {
        doc /* The windmill shall generate a rated electrical power of 2.5 MW 
             * at rated wind speed of 12 m/s.
             */
        subject windmill : Windmill;
        
        assert constraint {
            windmill.ratedPower >= 2500000.0 [W]
        }
    }

    requirement <'REQ-WM-003'> operationalWindRange {
        doc /* The windmill shall operate within wind speeds from 3.5 m/s 
             * (cut-in) to 25 m/s (cut-out) for safe and efficient operation.
             */
        subject windmill : Windmill;
        
        assert constraint {
            windmill.cutInWindSpeed == 3.5 [m/s] &&
            windmill.cutOutWindSpeed == 25.0 [m/s]
        }
    }

    requirement <'REQ-WM-004'> structuralIntegrity {
        doc /* The total mass of the windmill structure shall not exceed 
             * 270,000 kg to ensure structural integrity and foundation stability.
             */
        subject windmill : Windmill;
        
        assert constraint {
            windmill.totalMass <= 270000.0 [kg]
        }
    }

    requirement <'REQ-WM-005'> automaticControl {
        doc /* The windmill shall automatically adjust yaw angle and blade pitch 
             * to optimize power generation and ensure safe operation under varying 
             * wind conditions.
             */
        subject windmill : Windmill;
    }

    requirement <'REQ-WM-006'> emergencyShutdown {
        doc /* The windmill shall automatically engage brakes and feather blades 
             * when wind speed exceeds cut-out speed to prevent structural damage.
             */
        subject windmill : Windmill;
        
        assume constraint {
            windmill.controlSystem.currentWindSpeed >= windmill.cutOutWindSpeed
        }
        
        require constraint {
            windmill.nacelle.brakeSystem.isEngaged == true
        }
    }

    part windmillSystem : Windmill {
        attribute :>> totalMass = 266000.0 [kg];
        attribute :>> ratedPower = 2500000.0 [W];
        attribute :>> cutInWindSpeed = 3.5 [m/s];
        attribute :>> ratedWindSpeed = 12.0 [m/s];
        attribute :>> cutOutWindSpeed = 25.0 [m/s];
        attribute :>> hubHeight = 91.5 [m];
        attribute :>> rotorDiameter = 90.0 [m];
    }

    satisfy primaryFunction by windmillSystem;
    satisfy powerGeneration by windmillSystem;
    satisfy operationalWindRange by windmillSystem;
    satisfy structuralIntegrity by windmillSystem;
    satisfy automaticControl by windmillSystem;
    satisfy emergencyShutdown by windmillSystem;
}
