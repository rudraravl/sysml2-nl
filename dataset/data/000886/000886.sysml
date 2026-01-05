package GerotorHydraulicSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RotationalSpeed :> ISQ::AngularVelocityValue {
        attribute :>> num : Real;
        attribute :>> mRef : AngularVelocityUnit;
    }
    
    attribute def VolumetricFlowRate :> ISQ::VolumeFlowRateValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeFlowRateUnit;
    }
    
    attribute def HydraulicPressure :> ISQ::PressureValue {
        attribute :>> num : Real;
        attribute :>> mRef : PressureUnit;
    }
    
    attribute def FluidTemperature :> ISQ::ThermodynamicTemperatureValue {
        attribute :>> num : Real;
        attribute :>> mRef : ThermodynamicTemperatureUnit;
    }
    
    attribute def Displacement :> ISQ::VolumeValue {
        attribute :>> num : Real;
        attribute :>> mRef : VolumeUnit;
    }
    
    port def HydraulicFluidPort {
        attribute pressure : HydraulicPressure;
        attribute flowRate : VolumetricFlowRate;
        attribute temperature : FluidTemperature;
    }
    
    port def MechanicalDrivePort {
        attribute speed : RotationalSpeed;
        attribute torque : ISQ::TorqueValue;
    }
    
    item def HydraulicFluid {
        attribute viscosity : Real;
        attribute density : ISQ::DensityValue;
        attribute bulkModulus : HydraulicPressure;
    }
    
    part def InnerRotor {
        attribute numberOfLobes : ScalarValues::Integer;
        attribute pitchDiameter : ISQ::LengthValue;
        attribute axialLength : ISQ::LengthValue;
        attribute eccentricity : ISQ::LengthValue;
        
        port driveConnection : MechanicalDrivePort;
    }
    
    part def OuterRotor {
        attribute numberOfCavities : ScalarValues::Integer;
        attribute outerDiameter : ISQ::LengthValue;
        attribute axialLength : ISQ::LengthValue;
        
        port rotationInterface : MechanicalDrivePort;
    }
    
    part def PumpHousing {
        attribute inletPortDiameter : ISQ::LengthValue;
        attribute outletPortDiameter : ISQ::LengthValue;
        attribute housingThickness : ISQ::LengthValue;
        
        port inletPort : HydraulicFluidPort;
        port outletPort : HydraulicFluidPort;
    }
    
    part def DriveShaft {
        attribute shaftDiameter : ISQ::LengthValue;
        attribute shaftLength : ISQ::LengthValue;
        attribute maxTorque : ISQ::TorqueValue;
        
        port inputDrive : MechanicalDrivePort;
        port outputDrive : MechanicalDrivePort;
    }
    
    action def RotateInnerRotor {
        in driveSpeed : RotationalSpeed;
        in driveTorque : ISQ::TorqueValue;
        in eccentricOffset : ISQ::LengthValue;
        out innerRotorSpeed : RotationalSpeed;
        out outerRotorSpeed : RotationalSpeed;
    }
    
    action def ExpandChamberVolume {
        in innerSpeed : RotationalSpeed;
        in outerSpeed : RotationalSpeed;
        in lobeGeometry : ISQ::LengthValue;
        out expandedVolume : Displacement;
    }
    
    action def IntakeFluid {
        in chamberVolume : Displacement;
        in inletPressure : HydraulicPressure;
        in inletTemperature : FluidTemperature;
        out intakeFlowRate : VolumetricFlowRate;
    }
    
    action def CompressChamberVolume {
        in innerSpeed : RotationalSpeed;
        in outerSpeed : RotationalSpeed;
        in lobeGeometry : ISQ::LengthValue;
        out compressedVolume : Displacement;
    }
    
    action def DischargeFluid {
        in chamberVolume : Displacement;
        in outletPressure : HydraulicPressure;
        out dischargeFlowRate : VolumetricFlowRate;
        out dischargeTemperature : FluidTemperature;
    }
    
    action def PumpHydraulicFluid {
        in driveSpeed : RotationalSpeed;
        in driveTorque : ISQ::TorqueValue;
        in inletPressure : HydraulicPressure;
        in inletTemperature : FluidTemperature;
        in outletPressure : HydraulicPressure;
        in eccentricity : ISQ::LengthValue;
        in lobeGeometry : ISQ::LengthValue;
        out outputFlowRate : VolumetricFlowRate;
        out outputTemperature : FluidTemperature;
        
        first start;
        then merge pumpingCycle;
        then action rotateRotors : RotateInnerRotor {
            in driveSpeed = driveSpeed;
            in driveTorque = driveTorque;
            in eccentricOffset = eccentricity;
            out innerRotorSpeed;
            out outerRotorSpeed;
        }
        then action expandChamber : ExpandChamberVolume {
            in innerSpeed = rotateRotors.innerRotorSpeed;
            in outerSpeed = rotateRotors.outerRotorSpeed;
            in lobeGeometry = lobeGeometry;
            out expandedVolume;
        }
        then action intakeFluid : IntakeFluid {
            in chamberVolume = expandChamber.expandedVolume;
            in inletPressure = inletPressure;
            in inletTemperature = inletTemperature;
            out intakeFlowRate;
        }
        then action compressChamber : CompressChamberVolume {
            in innerSpeed = rotateRotors.innerRotorSpeed;
            in outerSpeed = rotateRotors.outerRotorSpeed;
            in lobeGeometry = lobeGeometry;
            out compressedVolume;
        }
        then action dischargeFluid : DischargeFluid {
            in chamberVolume = compressChamber.compressedVolume;
            in outletPressure = outletPressure;
            out dischargeFlowRate;
            out dischargeTemperature;
        }
        then assign outputFlowRate := dischargeFluid.dischargeFlowRate;
        then assign outputTemperature := dischargeFluid.dischargeTemperature;
        then pumpingCycle;
    }
    
    attribute def StartPumpCommand;
    attribute def StopPumpCommand;
    attribute def EmergencyStopCommand;
    
    state def GerotorPumpStates {
        entry; then stopped;
        
        state stopped {
            entry assign operatingSpeed := 0.0;
        }
        
        transition stopped_to_starting
            first stopped
            accept StartPumpCommand
            then starting;
        
        state starting {
            entry assign operatingSpeed := 0.0;
            do action accelerate;
        }
        
        transition starting_to_operational
            first starting
            if operatingSpeed >= targetSpeed
            then operational;
        
        state operational {
            do action pumpFluid : PumpHydraulicFluid;
        }
        
        transition operational_to_stopping
            first operational
            accept StopPumpCommand
            then stopping;
        
        transition operational_to_emergency
            first operational
            accept EmergencyStopCommand
            then emergency;
        
        state stopping {
            do action decelerate;
        }
        
        transition stopping_to_stopped
            first stopping
            if operatingSpeed <= 0.0
            then stopped;
        
        state emergency {
            entry assign operatingSpeed := 0.0;
        }
        
        transition emergency_to_stopped
            first emergency
            accept StartPumpCommand
            then stopped;
        
        attribute operatingSpeed : RotationalSpeed;
        attribute targetSpeed : RotationalSpeed;
    }
    
    part def GerotorPump {
        doc /*
            A gerotor pump is a positive displacement hydraulic pump that uses an inner rotor 
            with external lobes rotating eccentrically inside an outer rotor with internal cavities.
            
            The primary function is to convert mechanical rotational energy into hydraulic energy 
            by continuously transferring fluid from a low-pressure inlet to a high-pressure outlet.
            
            As the inner rotor turns, the varying volume between the rotor lobes creates expanding 
            chambers on the inlet side that draw fluid in, and contracting chambers on the outlet 
            side that force fluid out under pressure. This gerotor mechanism provides smooth, 
            continuous flow with minimal pulsation, making it ideal for lubrication systems, 
            fuel transfer, and hydraulic power applications.
        */
        
        attribute ratedFlowRate : VolumetricFlowRate;
        attribute maximumPressure : HydraulicPressure;
        attribute ratedSpeed : RotationalSpeed;
        attribute volumetricDisplacement : Displacement;
        
        port fluidInlet : HydraulicFluidPort;
        port fluidOutlet : HydraulicFluidPort;
        port mechanicalDrive : MechanicalDrivePort;
        
        part innerRotor : InnerRotor {
            attribute :>> numberOfLobes = 6;
            attribute :>> pitchDiameter = 30.0 [SI::mm];
            attribute :>> axialLength = 25.0 [SI::mm];
            attribute :>> eccentricity = 3.0 [SI::mm];
        }
        
        part outerRotor : OuterRotor {
            attribute :>> numberOfCavities = 7;
            attribute :>> outerDiameter = 50.0 [SI::mm];
            attribute :>> axialLength = 25.0 [SI::mm];
        }
        
        part housing : PumpHousing {
            attribute :>> inletPortDiameter = 10.0 [SI::mm];
            attribute :>> outletPortDiameter = 10.0 [SI::mm];
            attribute :>> housingThickness = 8.0 [SI::mm];
        }
        
        part driveShaft : DriveShaft {
            attribute :>> shaftDiameter = 12.0 [SI::mm];
            attribute :>> shaftLength = 40.0 [SI::mm];
            attribute :>> maxTorque = 50.0 [SI::N * SI::m];
        }
        
        connection driveConnection : MechanicalDrivePort
            connect mechanicalDrive to driveShaft.inputDrive;
        
        connection innerRotorDrive : MechanicalDrivePort
            connect driveShaft.outputDrive to innerRotor.driveConnection;
        
        connection inletFluidConnection : HydraulicFluidPort
            connect fluidInlet to housing.inletPort;
        
        connection outletFluidConnection : HydraulicFluidPort
            connect housing.outletPort to fluidOutlet;
        
        perform action pumpingAction : PumpHydraulicFluid {
            in driveSpeed = mechanicalDrive.speed;
            in driveTorque = mechanicalDrive.torque;
            in inletPressure = fluidInlet.pressure;
            in inletTemperature = fluidInlet.temperature;
            in outletPressure = fluidOutlet.pressure;
            in eccentricity = innerRotor.eccentricity;
            in lobeGeometry = innerRotor.pitchDiameter;
            out outputFlowRate;
            out outputTemperature;
        }
        
        exhibit state pumpStateMachine : GerotorPumpStates {
            attribute :>> targetSpeed = ratedSpeed;
        }
    }
    
    part gerotorPumpSystem : GerotorPump {
        attribute :>> ratedFlowRate = 20.0 [SI::L / SI::min];
        attribute :>> maximumPressure = 250.0 [SI::Pa] * 1.0e5;
        attribute :>> ratedSpeed = 2500.0 [SI::rad / SI::s] * (2.0 * 3.14159 / 60.0);
        attribute :>> volumetricDisplacement = 8.0 [SI::m^3] * 1.0e-6;
    }
    
    requirement def FlowDeliveryRequirement {
        doc /*
            The gerotor pump shall deliver hydraulic fluid at the specified rated flow rate 
            when operating at rated speed under nominal inlet and outlet pressure conditions.
        */
        
        subject pump : GerotorPump;
        
        require constraint {
            pump.pumpingAction.outputFlowRate >= pump.ratedFlowRate * 0.92 and
            pump.pumpingAction.outputFlowRate <= pump.ratedFlowRate * 1.08
        }
    }
    
    requirement def PressureRatingRequirement {
        doc /*
            The gerotor pump shall withstand continuous operation at outlet pressures 
            up to the specified maximum pressure without mechanical failure or excessive leakage.
        */
        
        subject pump : GerotorPump;
        
        require constraint {
            pump.fluidOutlet.pressure <= pump.maximumPressure
        }
    }
    
    requirement def RotorGeometryRequirement {
        doc /*
            The outer rotor shall have exactly one more cavity than the inner rotor has lobes 
            to ensure proper gerotor meshing and volumetric displacement.
        */
        
        subject pump : GerotorPump;
        
        require constraint {
            pump.outerRotor.numberOfCavities == pump.innerRotor.numberOfLobes + 1
        }
    }
    
    requirement def VolumetricEfficiencyRequirement {
        doc /*
            The gerotor pump shall maintain volumetric efficiency above 90 percent 
            across the operating pressure range to minimize internal leakage losses.
        */
        
        subject pump : GerotorPump;
        
        require constraint {
            pump.pumpingAction.outputFlowRate >= 
                (pump.volumetricDisplacement * pump.mechanicalDrive.speed) * 0.90
        }
    }
    
    requirement gerotorSystemRequirements {
        doc /*
            Top-level requirements governing the design, performance, and operation 
            of the gerotor-based hydraulic pumping system.
        */
        
        require flowDeliveryReq : FlowDeliveryRequirement;
        require pressureRatingReq : PressureRatingRequirement;
        require rotorGeometryReq : RotorGeometryRequirement;
        require volumetricEfficiencyReq : VolumetricEfficiencyRequirement;
    }
}
