package 'Propeller System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ControlSignal;
    attribute def PropellerCommand;
    
    part def Motor {
        attribute ratedPower : PowerValue;
        attribute efficiency : Real;
        in port controlInput : ControlSignal;
        in port electricalPower : PowerValue;
        out port mechanicalTorque : TorqueValue;
        out port rotationalSpeed : AngularVelocityValue;
        
        perform action convertPowerToRotation;
    }
    
    part def DriveShaft {
        attribute shaftDiameter : LengthValue;
        attribute shaftLength : LengthValue;
        attribute shaftMass : MassValue;
        in port inputTorque : TorqueValue;
        in port inputSpeed : AngularVelocityValue;
        out port outputTorque : TorqueValue;
        out port outputSpeed : AngularVelocityValue;
        
        perform action transmitRotationalPower;
    }
    
    part def PropellerBlade {
        attribute bladeLength : LengthValue;
        attribute bladePitch : Real;
        attribute bladeArea : AreaValue;
        attribute bladeMass : MassValue;
    }
    
    part def PropellerHub {
        attribute hubDiameter : LengthValue;
        attribute hubMass : MassValue;
        attribute numberOfBlades : Integer;
    }
    
    part def Propeller {
        attribute propellerDiameter : LengthValue;
        attribute totalPropellerMass : MassValue;
        
        part hub : PropellerHub;
        part blades : PropellerBlade[*];
        
        in port driveTorque : TorqueValue;
        in port driveSpeed : AngularVelocityValue;
        out port thrustForce : ForceValue;
        
        perform action generateThrust;
    }
    
    part def PropellerSystem {
        attribute systemMass : MassValue;
        attribute maxThrust : ForceValue;
        
        in port powerSupply : PowerValue;
        in port commandSignal : PropellerCommand;
        out port systemThrust : ForceValue;
        
        part motor : Motor;
        part shaft : DriveShaft;
        part propeller : Propeller;
        
        connect motor.mechanicalTorque to shaft.inputTorque;
        connect motor.rotationalSpeed to shaft.inputSpeed;
        connect shaft.outputTorque to propeller.driveTorque;
        connect shaft.outputSpeed to propeller.driveSpeed;
        
        perform action providePropulsion;
    }
    
    action def ConvertElectricalToMechanical {
        in electricalPower : PowerValue;
        in controlSignal : ControlSignal;
        in motorEfficiency : Real;
        out torque : TorqueValue;
        out speed : AngularVelocityValue;
    }
    
    action def TransmitRotationalPower {
        in inputTorque : TorqueValue;
        in inputSpeed : AngularVelocityValue;
        out outputTorque : TorqueValue;
        out outputSpeed : AngularVelocityValue;
    }
    
    action def GenerateAerodynamicThrust {
        in rotationalSpeed : AngularVelocityValue;
        in driveTorque : TorqueValue;
        in bladePitch : Real;
        in bladeArea : AreaValue;
        in fluidDensity : DensityValue;
        out thrustForce : ForceValue;
        out inducedVelocity : SpeedValue;
    }
    
    action def ProvidePropulsion {
        in powerInput : PowerValue;
        in command : PropellerCommand;
        in ambientDensity : DensityValue;
        out thrust : ForceValue;
        
        first start;
        then action motorConversion : ConvertElectricalToMechanical {
            in electricalPower = powerInput;
            in controlSignal = command;
            in motorEfficiency : Real;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
        }
        flow motorConversion.torque to shaftTransmission.inputTorque;
        flow motorConversion.speed to shaftTransmission.inputSpeed;
        then action shaftTransmission : TransmitRotationalPower {
            in inputTorque : TorqueValue;
            in inputSpeed : AngularVelocityValue;
            out outputTorque : TorqueValue;
            out outputSpeed : AngularVelocityValue;
        }
        flow shaftTransmission.outputTorque to thrustGeneration.driveTorque;
        flow shaftTransmission.outputSpeed to thrustGeneration.rotationalSpeed;
        then action thrustGeneration : GenerateAerodynamicThrust {
            in rotationalSpeed : AngularVelocityValue;
            in driveTorque : TorqueValue;
            in bladePitch : Real;
            in bladeArea : AreaValue;
            in fluidDensity = ambientDensity;
            out thrustForce : ForceValue;
            out inducedVelocity : SpeedValue;
        }
        then assign thrust := thrustGeneration.thrustForce;
        then done;
    }
    
    part propellerSystemInstance : PropellerSystem {
        attribute :>> systemMass = 25.0;
        attribute :>> maxThrust = 5000.0;
        
        part :>> motor : Motor {
            attribute :>> ratedPower = 15000.0;
            attribute :>> efficiency = 0.92;
        }
        
        part :>> shaft : DriveShaft {
            attribute :>> shaftDiameter = 0.08;
            attribute :>> shaftLength = 0.5;
            attribute :>> shaftMass = 3.5;
        }
        
        part :>> propeller : Propeller {
            attribute :>> propellerDiameter = 2.4;
            attribute :>> totalPropellerMass = 18.0;
            
            part :>> hub : PropellerHub {
                attribute :>> hubDiameter = 0.35;
                attribute :>> hubMass = 6.0;
                attribute :>> numberOfBlades = 4;
            }
            
            part :>> blades : PropellerBlade[4] {
                attribute :>> bladeLength = 1.025;
                attribute :>> bladePitch = 28.0;
                attribute :>> bladeArea = 0.15;
                attribute :>> bladeMass = 3.0;
            }
        }
        
        perform action providePropulsion : ProvidePropulsion {
            in powerInput = propellerSystemInstance::powerSupply;
            in command = propellerSystemInstance::commandSignal;
            in ambientDensity : DensityValue;
            out thrust = propellerSystemInstance::systemThrust;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'R-1'> primaryFunction : FunctionalRequirement {
        doc /* The Propeller System shall convert electrical power into forward thrust 
                by rotating propeller blades to accelerate fluid mass. */
        subject propellerSystemInstance;
    }
    
    requirement <'R-1.1'> minimumThrustRequirement : PerformanceRequirement {
        doc /* The Propeller System shall generate a minimum thrust of 4500 N 
                at rated power input. */
        refine primaryFunction;
        subject propellerSystemInstance;
        require constraint {
            propellerSystemInstance.systemThrust >= 4500.0
        }
    }
    
    requirement <'R-1.2'> efficiencyRequirement : PerformanceRequirement {
        doc /* The Propeller System shall achieve a minimum overall efficiency 
                of 75% in converting electrical power to thrust power. */
        refine primaryFunction;
        subject propellerSystemInstance;
        require constraint {
            propellerSystemInstance.motor.efficiency >= 0.75
        }
    }
    
    requirement <'R-2'> structuralIntegrity : SafetyRequirement {
        doc /* The Propeller blades shall withstand operational loads with 
                a safety factor of at least 2.5. */
        subject propellerSystemInstance.propeller;
    }
    
    requirement <'R-3'> operationalRange : PerformanceRequirement {
        doc /* The Propeller System shall operate continuously across a range 
                of rotational speeds from 500 to 3000 RPM. */
        subject propellerSystemInstance;
    }
}
