package PressureBasedSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure :> pressure {
        unit = SI::pascal;
    }

    attribute def Temperature :> thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def VolumeFlowRate :> volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def TimeDuration :> time {
        unit = SI::second;
    }

    attribute def Percent :> Real {
        range = "0..100";
    }

    item def PressurizedFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : VolumeFlowRate;
    }

    item def PressureSample {
        attribute measuredPressure : Pressure;
        attribute sampleTime : TimeDuration;
        attribute sensorHealth : Percent;
    }

    item def ValveCommand {
        attribute requestedOpening : Percent;
        attribute commandTime : TimeDuration;
    }

    item def PumpCommand {
        attribute requestedSpeed : Percent;
        attribute commandTime : TimeDuration;
    }

    item def AlarmSignal {
        attribute alarmPressure : Pressure;
        attribute severity : Percent;
        attribute active : Boolean;
    }

    port def FluidInletPort {
        in item incomingFluid : PressurizedFluid;
    }

    port def FluidOutletPort {
        out item outgoingFluid : PressurizedFluid;
    }

    port def PressureMeasurementPort {
        out item pressureSample : PressureSample;
    }

    port def PressureCommandPort {
        in item pressureSetpoint : Pressure;
    }

    port def ValveControlPort {
        in item valveCommand : ValveCommand;
    }

    port def PumpControlPort {
        in item pumpCommand : PumpCommand;
    }

    port def AlarmPort {
        out item alarmSignal : AlarmSignal;
    }

    part def PressureSensor {
        port sensedFluid : FluidInletPort;
        port measurementOut : PressureMeasurementPort;

        attribute calibratedRangeLow : Pressure = 0.0 [SI::kilopascal];
        attribute calibratedRangeHigh : Pressure = 800.0 [SI::kilopascal];
        attribute responseTime : TimeDuration = 0.05 [SI::second];
        attribute accuracy : Percent = 99.0;

        action measurePressure {
            in item fluid : PressurizedFluid;
            out item sample : PressureSample;
            attribute conversionDelay : TimeDuration = 0.05 [SI::second];
        }
    }

    part def ElectricPump {
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        port controlIn : PumpControlPort;

        attribute maximumDischargePressure : Pressure = 700.0 [SI::kilopascal];
        attribute minimumSpeed : Percent = 0.0;
        attribute maximumSpeed : Percent = 100.0;
        attribute nominalSpeed : Percent = 55.0;

        action increasePressure {
            in item inletFluid : PressurizedFluid;
            in item command : PumpCommand;
            out item outletFluid : PressurizedFluid;
        }
    }

    part def ModulatingReliefValve {
        port fluidIn : FluidInletPort;
        port fluidOut : FluidOutletPort;
        port controlIn : ValveControlPort;

        attribute failSafeOpening : Percent = 100.0;
        attribute minimumOpening : Percent = 0.0;
        attribute maximumOpening : Percent = 100.0;
        attribute nominalOpening : Percent = 25.0;

        action relievePressure {
            in item inletFluid : PressurizedFluid;
            in item command : ValveCommand;
            out item outletFluid : PressurizedFluid;
        }
    }

    part def PressureController {
        port measuredPressureIn : PressureMeasurementPort;
        port setpointIn : PressureCommandPort;
        port pumpCommandOut : PumpControlPort;
        port valveCommandOut : ValveControlPort;
        port alarmOut : AlarmPort;

        attribute targetPressure : Pressure = 350.0 [SI::kilopascal];
        attribute lowLimit : Pressure = 300.0 [SI::kilopascal];
        attribute highLimit : Pressure = 400.0 [SI::kilopascal];
        attribute shutdownLimit : Pressure = 500.0 [SI::kilopascal];
        attribute controlPeriod : TimeDuration = 0.10 [SI::second];

        action computeRegulationCommand {
            in item sample : PressureSample;
            in item setpoint : Pressure;
            out item pumpCommand : PumpCommand;
            out item valveCommand : ValveCommand;
            out item alarm : AlarmSignal;
        }

        state controllerOperatingState {
            entry; then initializing;

            state initializing;
            state regulating;
            state relieving;
            state alarmed;
            state shutdown;

            transition initializationComplete
                first initializing
                then regulating;

            transition pressureBelowLowLimit
                first regulating
                then regulating
                if measuredPressureIn::pressureSample::measuredPressure < lowLimit;

            transition pressureWithinBand
                first regulating
                then regulating
                if measuredPressureIn::pressureSample::measuredPressure >= lowLimit and measuredPressureIn::pressureSample::measuredPressure <= highLimit;

            transition pressureAboveHighLimit
                first regulating
                then relieving
                if measuredPressureIn::pressureSample::measuredPressure > highLimit;

            transition pressureRecovered
                first relieving
                then regulating
                if measuredPressureIn::pressureSample::measuredPressure <= targetPressure;

            transition pressureUnsafe
                first regulating
                then alarmed
                if measuredPressureIn::pressureSample::measuredPressure >= shutdownLimit;

            transition relievedPressureUnsafe
                first relieving
                then alarmed
                if measuredPressureIn::pressureSample::measuredPressure >= shutdownLimit;

            transition operatorShutdown
                first alarmed
                then shutdown;
        }
    }

    part def PressureVessel {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port sensorTap : FluidOutletPort;

        attribute designPressure : Pressure = 800.0 [SI::kilopascal];
        attribute normalOperatingPressure : Pressure = 350.0 [SI::kilopascal];
        attribute minimumOperatingPressure : Pressure = 300.0 [SI::kilopascal];
        attribute maximumOperatingPressure : Pressure = 400.0 [SI::kilopascal];
    }

    part def OperatorInterface {
        port setpointOut : PressureCommandPort;
        port alarmIn : AlarmPort;

        attribute defaultSetpoint : Pressure = 350.0 [SI::kilopascal];

        action displayPressureStatus {
            in item sample : PressureSample;
            in item alarm : AlarmSignal;
        }
    }

    part def PressureRegulationSystem {
        doc /* Primary function: maintain the pressure of a contained fluid process near a commanded setpoint by measuring pressure, driving a pump, modulating a relief valve, and issuing alarms when pressure exceeds safe limits. */

        part vessel : PressureVessel;
        part pump : ElectricPump;
        part reliefValve : ModulatingReliefValve;
        part pressureSensor : PressureSensor;
        part controller : PressureController;
        part operatorInterface : OperatorInterface;

        port processInlet : FluidInletPort;
        port processOutlet : FluidOutletPort;

        attribute commandedPressure : Pressure = 350.0 [SI::kilopascal];
        attribute allowablePressureError : Pressure = 10.0 [SI::kilopascal];
        attribute maximumSafePressure : Pressure = 500.0 [SI::kilopascal];

        connect processInlet to pump.fluidIn;
        connect pump.fluidOut to vessel.inlet;
        connect vessel.outlet to reliefValve.fluidIn;
        connect reliefValve.fluidOut to processOutlet;
        connect vessel.sensorTap to pressureSensor.sensedFluid;
        connect pressureSensor.measurementOut to controller.measuredPressureIn;
        connect operatorInterface.setpointOut to controller.setpointIn;
        connect controller.pumpCommandOut to pump.controlIn;
        connect controller.valveCommandOut to reliefValve.controlIn;
        connect controller.alarmOut to operatorInterface.alarmIn;

        action regulateProcessPressure {
            in item inletFluid : PressurizedFluid;
            in item setpoint : Pressure;
            out item outletFluid : PressurizedFluid;
            out item alarm : AlarmSignal;

            first startPump;
            then measure;
            then compareToSetpoint;
            then commandPumpAndValve;
            then verifySafePressure;

            action startPump : pump.increasePressure;
            action measure : pressureSensor.measurePressure;
            action compareToSetpoint : controller.computeRegulationCommand;
            action commandPumpAndValve;
            action verifySafePressure;
        }
    }

    requirement def MaintainPressureRequirement {
        subject system : PressureRegulationSystem;

        require constraint {
            system.commandedPressure >= 300.0 [SI::kilopascal] and
            system.commandedPressure <= 400.0 [SI::kilopascal]
        }

        doc /* The system shall regulate process pressure to the commanded pressure band during normal operation. */
    }

    requirement def PressureAccuracyRequirement {
        subject system : PressureRegulationSystem;

        require constraint {
            system.allowablePressureError <= 10.0 [SI::kilopascal]
        }

        doc /* The regulated process pressure shall remain within plus or minus 10 kPa of the commanded pressure after stabilization. */
    }

    requirement def OverPressureProtectionRequirement {
        subject system : PressureRegulationSystem;

        require constraint {
            system.maximumSafePressure <= 500.0 [SI::kilopascal]
        }

        doc /* The system shall command pressure relief and alarm before process pressure exceeds 500 kPa. */
    }

    requirement def SensorResponseRequirement {
        subject sensor : PressureSensor;

        require constraint {
            sensor.responseTime <= 0.10 [SI::second]
        }

        doc /* The pressure sensor shall provide a pressure sample within 0.10 seconds of a pressure change. */
    }

    requirement def VesselDesignPressureRequirement {
        subject vessel : PressureVessel;

        require constraint {
            vessel.designPressure >= 800.0 [SI::kilopascal]
        }

        doc /* The pressure vessel shall be rated for at least 800 kPa. */
    }

    satisfy MaintainPressureRequirement by PressureRegulationSystem;
    satisfy PressureAccuracyRequirement by PressureRegulationSystem;
    satisfy OverPressureProtectionRequirement by PressureRegulationSystem;
    satisfy SensorResponseRequirement by PressureSensor;
    satisfy VesselDesignPressureRequirement by PressureVessel;
}