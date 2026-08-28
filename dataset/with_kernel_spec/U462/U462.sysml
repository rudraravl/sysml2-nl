package 'Industrial Pumping System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def ProcessFluid;
    item def FlowMeasurement {
        attribute value : VolumeFlowRate;
    }
    item def PressureMeasurement {
        attribute value : Pressure;
    }
    item def SpeedCommand {
        attribute targetSpeed : AngularVelocity;
    }
    item def FrequencyCommand {
        attribute targetFrequency : Frequency;
    }

    calc def AffinityLawFlow {
        in N1 : AngularVelocity;
        in N2 : AngularVelocity;
        in Q1 : VolumeFlowRate;
        return Q2 : VolumeFlowRate = Q1 * (N2 / N1);
    }

    calc def AffinityLawHead {
        in N1 : AngularVelocity;
        in N2 : AngularVelocity;
        in H1 : Pressure;
        return H2 : Pressure = H1 * (N2 / N1)^2;
    }

    calc def AffinityLawPower {
        in N1 : AngularVelocity;
        in N2 : AngularVelocity;
        in P1 : Power;
        return P2 : Power = P1 * (N2 / N1)^3;
    }

    part def CentrifugalPump {
        port fluidInPort { in fluid : ProcessFluid; }
        port fluidOutPort { out fluid : ProcessFluid; }
        port drivePort { in speed : AngularVelocity; }
        attribute nominalSpeed : AngularVelocity;
        attribute nominalFlow : VolumeFlowRate;
        attribute nominalHead : Pressure;
        attribute nominalPower : Power;
    }

    part def ElectricMotor {
        port drivePort { in frequency : Frequency; }
        port shaftPort { out speed : AngularVelocity; }
        attribute ratedPower : Power;
        attribute ratedFrequency : Frequency;
        attribute ratedSpeed : AngularVelocity;
    }

    part def VariableFrequencyDrive {
        port commandPort { in speedCommand : SpeedCommand; }
        port motorPort { out frequency : Frequency; }
        attribute minFrequency : Frequency;
        attribute maxFrequency : Frequency;
    }

    part def ProcessController {
        port flowSetpointPort { in flowSetpoint : VolumeFlowRate; }
        port pressureSetpointPort { in pressureSetpoint : Pressure; }
        port flowFeedbackPort { in flowMeasurement : FlowMeasurement; }
        port pressureFeedbackPort { in pressureMeasurement : PressureMeasurement; }
        port speedCommandPort { out speedCommand : SpeedCommand; }
        attribute currentSpeed : AngularVelocity;
        attribute minSpeed : AngularVelocity;
        attribute maxSpeed : AngularVelocity;
        attribute setpointActive : Boolean;
        attribute deviationDetected : Boolean;

        action controllerBehavior {
            action receiveFlowMeasurement accept FlowMeasurement via flowFeedbackPort;
            then action receivePressureMeasurement accept PressureMeasurement via pressureFeedbackPort;
            then action compareSetpoints;
            then action calculateSpeedChange;
            then action sendSpeedCommand send new SpeedCommand() via speedCommandPort;
        }

        state def controllerStateMachine {
            state Idle;
            state Monitoring;
            state Adjusting;
            transition from Idle to Monitoring when setpointActive;
            transition from Monitoring to Adjusting when deviationDetected;
            transition from Adjusting to Monitoring;
        }
    }

    part def FlowTransmitter {
        port fluidPort { in fluid : ProcessFluid; }
        port outputPort { out flowMeasurement : FlowMeasurement; }
        attribute measurementRange : VolumeFlowRate;
    }

    part def PressureTransmitter {
        port fluidPort { in fluid : ProcessFluid; }
        port outputPort { out pressureMeasurement : PressureMeasurement; }
        attribute measurementRange : Pressure;
    }

    part def Piping {
        port inletPort { in fluid : ProcessFluid; }
        port outletPort { out fluid : ProcessFluid; }
        port flowTapPort { out fluid : ProcessFluid; }
        port pressureTapPort { out fluid : ProcessFluid; }
    }

    part def PumpingSystem {
        port processFluidIn { in fluid : ProcessFluid; }
        port processFluidOut { out fluid : ProcessFluid; }

        part processController : ProcessController;
        part vfd : VariableFrequencyDrive;
        part motor : ElectricMotor;
        part pump : CentrifugalPump;
        part flowTransmitter : FlowTransmitter;
        part pressureTransmitter : PressureTransmitter;
        part suctionPiping : Piping;
        part dischargePiping : Piping;

        flow processInletFlow of ProcessFluid
            from processFluidIn.fluid to suctionPiping.inletPort.fluid;
        flow suctionFluidFlow of ProcessFluid
            from suctionPiping.outletPort.fluid to pump.fluidInPort.fluid;
        flow dischargeFluidFlow of ProcessFluid
            from pump.fluidOutPort.fluid to dischargePiping.inletPort.fluid;
        flow processOutletFlow of ProcessFluid
            from dischargePiping.outletPort.fluid to processFluidOut.fluid;
        flow flowTapFlow of ProcessFluid
            from dischargePiping.flowTapPort.fluid to flowTransmitter.fluidPort.fluid;
        flow pressureTapFlow of ProcessFluid
            from dischargePiping.pressureTapPort.fluid to pressureTransmitter.fluidPort.fluid;
        flow speedCommandFlow of SpeedCommand
            from processController.speedCommandPort.speedCommand to vfd.commandPort.speedCommand;
        flow frequencyFlow of Frequency
            from vfd.motorPort.frequency to motor.drivePort.frequency;
        flow motorSpeedFlow of AngularVelocity
            from motor.shaftPort.speed to pump.drivePort.speed;
        flow flowMeasurementFlow of FlowMeasurement
            from flowTransmitter.outputPort.flowMeasurement to processController.flowFeedbackPort.flowMeasurement;
        flow pressureMeasurementFlow of PressureMeasurement
            from pressureTransmitter.outputPort.pressureMeasurement to processController.pressureFeedbackPort.pressureMeasurement;
    }

    requirement def FlowControlRequirement {
        subject pumpingSystem : PumpingSystem;
        requirement {
            subject :>> pumpingSystem;
            the pumpingSystem shall maintain the process fluid flow rate within plus or minus 2 percent of the flow setpoint.
        }
    }

    requirement def PressureControlRequirement {
        subject pumpingSystem : PumpingSystem;
        requirement {
            subject :>> pumpingSystem;
            the pumpingSystem shall maintain the process fluid pressure within plus or minus 5 percent of the pressure setpoint.
        }
    }

    requirement def EnergyEfficiencyRequirement {
        subject pumpingSystem : PumpingSystem;
        requirement {
            subject :>> pumpingSystem;
            the pumpingSystem shall optimize energy consumption by using affinity-law-based variable speed control rather than throttling valves.
        }
    }

    requirement def SafeOperationRequirement {
        subject pumpingSystem : PumpingSystem;
        requirement {
            subject :>> pumpingSystem;
            the pumpingSystem shall operate the pump speed within the range defined by minSpeed and maxSpeed.
        }
    }

    part pumpingSystem : PumpingSystem {
        satisfy flowControlReq : FlowControlRequirement;
        satisfy pressureControlReq : PressureControlRequirement;
        satisfy energyEfficiencyReq : EnergyEfficiencyRequirement;
        satisfy safeOperationReq : SafeOperationRequirement;
    }
}
