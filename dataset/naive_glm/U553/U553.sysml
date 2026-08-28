package FluidPumpingSystem {
    import ScalarValues::*;
    import ISQ::*;

    attribute def PressureValue :> Real { unit = 'Pa'; }
    attribute def FlowRateValue :> Real { unit = 'm3/s'; }
    attribute def RotationalSpeedValue :> Real { unit = 'rad/s'; }
    attribute def TorqueValue :> Real { unit = 'N*m'; }
    attribute def VolumeValue :> Real { unit = 'm3'; }

    item def HydraulicFluid;

    port def FluidPort {
        out item fluid: HydraulicFluid;
        attribute pressure: PressureValue;
        attribute flowRate: FlowRateValue;
    }
    
    port def MechanicalDrivePort {
        attribute speed: RotationalSpeedValue;
        attribute torque: TorqueValue;
    }

    part def SourceReservoir {
        port fluidOut : FluidPort;
        port fluidReturn : FluidPort;
        attribute volume: VolumeValue;
    }

    part def Strainer {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def PressureSensor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute measuredPressure: PressureValue;
    }

    part def ElectricMotor {
        port driveOut : MechanicalDrivePort;
        attribute power: Real;
    }

    part def DriveShaft {
        port driveIn : MechanicalDrivePort;
        port driveOut : MechanicalDrivePort;
    }

    part def Bearing;
    part def Seal;

    part def Rotor {
        port driveIn : MechanicalDrivePort;
    }
    part def Vane;
    part def Housing {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def RotaryVanePump {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port driveIn : MechanicalDrivePort;
        
        part rotor: Rotor;
        part vanes: Vane[4..6];
        part housing: Housing;
        part shaft: DriveShaft;
        part bearings: Bearing[2];
        part seals: Seal[2];
        
        connection driveConnection: MechanicalDrivePort connect driveIn to shaft.driveIn;
        connection shaftToRotor: MechanicalDrivePort connect shaft.driveOut to rotor.driveIn;
        connection internalFluidIn: FluidPort connect fluidIn to housing.fluidIn;
        connection internalFluidOut: FluidPort connect housing.fluidOut to fluidOut;
    }

    part def CheckValve {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def FlowMeter {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute measuredFlowRate: FlowRateValue;
    }

    part def PressureReliefValve {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port reliefOut : FluidPort;
        attribute reliefPressure: PressureValue;
        
        state machine ReliefValveStates {
            state Closed;
            state Open;
            
            transition from Closed to Open when fluidIn.pressure > reliefPressure;
            transition from Open to Closed when fluidIn.pressure <= reliefPressure;
        }
    }

    part def DestinationVessel {
        port fluidIn : FluidPort;
        attribute maxPressure: PressureValue;
    }

    part def FluidPumpingSystem {
        part reservoir: SourceReservoir;
        part strainer: Strainer;
        part suctionSensor: PressureSensor;
        part pump: RotaryVanePump;
        part motor: ElectricMotor;
        part checkValve: CheckValve;
        part dischargeSensor: PressureSensor;
        part flowMeter: FlowMeter;
        part reliefValve: PressureReliefValve;
        part destination: DestinationVessel;
        
        connection motorToPump: MechanicalDrivePort connect motor.driveOut to pump.driveIn;
        
        connection reservoirToStrainer: FluidPort connect reservoir.fluidOut to strainer.fluidIn;
        connection strainerToSuctionSensor: FluidPort connect strainer.fluidOut to suctionSensor.fluidIn;
        connection suctionSensorToPump: FluidPort connect suctionSensor.fluidOut to pump.fluidIn;
        
        connection pumpToCheckValve: FluidPort connect pump.fluidOut to checkValve.fluidIn;
        connection checkValveToRelief: FluidPort connect checkValve.fluidOut to reliefValve.fluidIn;
        connection reliefToDischargeSensor: FluidPort connect reliefValve.fluidOut to dischargeSensor.fluidIn;
        connection dischargeSensorToFlowMeter: FluidPort connect dischargeSensor.fluidOut to flowMeter.fluidIn;
        connection flowMeterToDestination: FluidPort connect flowMeter.fluidOut to destination.fluidIn;
        
        connection reliefToReservoir: FluidPort connect reliefValve.reliefOut to reservoir.fluidReturn;
    }

    requirement def PumpingSystemRequirements {
        attribute requiredFlowRate: FlowRateValue = 0.01;
        attribute requiredDischargePressure: PressureValue = 500000;
        attribute maxSuctionPressure: PressureValue = 100000;
        attribute requiredEfficiency: Real = 0.85;
        
        requirement FlowRateRequirement {
            subject system: FluidPumpingSystem;
            require system.flowMeter.measuredFlowRate >= requiredFlowRate;
        }
        
        requirement DischargePressureRequirement {
            subject system: FluidPumpingSystem;
            require system.dischargeSensor.measuredPressure >= requiredDischargePressure;
        }
        
        requirement SafetyReliefRequirement {
            subject system: FluidPumpingSystem;
            require system.reliefValve.reliefPressure == 600000;
        }
    }
}
