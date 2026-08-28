package StabilizingUtensil {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----
    value def FrequencyHz :> Real { unit 'Hz'; }
    value def DisplacementMM :> Real { unit 'mm'; }
    value def AngleDeg :> Real { unit 'deg'; }
    value def AngularRateDps :> Real { unit 'deg/s'; }
    value def VoltageV :> Real { unit 'V'; }
    value def CurrentA :> Real { unit 'A'; }
    value def PowerW :> Real { unit 'W'; }
    value def TimeS :> Real { unit 's'; }
    value def MassG :> Real { unit 'g'; }
    value def EnergyWh :> Real { unit 'W*h'; }
    value def Percent :> Real { unit '%'; }

    // ---- Item definitions ----
    item def TremorData {
        attribute frequency : FrequencyHz;
        attribute amplitude : DisplacementMM;
        attribute pitchRate : AngularRateDps;
        attribute rollRate : AngularRateDps;
        attribute timestamp : TimeS;
    }

    item def CorrectionCommand {
        attribute pitchCorrection : AngleDeg;
        attribute rollCorrection : AngleDeg;
        attribute timestamp : TimeS;
    }

    item def PowerFlow {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    item def BatteryStatus {
        attribute stateOfCharge : Percent;
        attribute voltage : VoltageV;
    }

    // ---- Port definitions ----
    port def TremorDataOut { out tremor : TremorData; }
    port def TremorDataIn { in tremor : TremorData; }
    port def CorrectionCommandOut { out command : CorrectionCommand; }
    port def CorrectionCommandIn { in command : CorrectionCommand; }
    port def PowerOut { out power : PowerFlow; }
    port def PowerIn { in power : PowerFlow; }
    port def BatteryStatusOut { out status : BatteryStatus; }
    port def BatteryStatusIn { in status : BatteryStatus; }
    port def ChargingIn { in chargePower : PowerFlow; }

    // ---- Requirements ----
    requirement def StabilizationRequirement {
        subject device :> StabilizingUtensil;
        objective {
            doc "The device shall actively cancel hand tremor motion to keep the utensil attachment level.";
        }
        require device.tremorCancellationEffectiveness >= 70.0 '%';
    }

    requirement def SensingRequirement {
        subject sensor :> InertialSensor;
        objective {
            doc "The inertial sensor shall detect tremor frequencies from 3 to 12 Hz and amplitudes up to 30 mm.";
        }
        require sensor.minDetectableFrequency <= 3.0 'Hz';
        require sensor.maxDetectableFrequency >= 12.0 'Hz';
        require sensor.maxDetectableAmplitude >= 30.0 'mm';
    }

    requirement def LatencyRequirement {
        subject processor :> StabilizationProcessor;
        objective {
            doc "The stabilization processor shall compute correction commands within 20 ms of receiving tremor data.";
        }
        require processor.maxLatency <= 0.02 's';
    }

    requirement def ActuationRequirement {
        subject actuator :> GimbalActuator;
        objective {
            doc "The gimbal actuator shall move the utensil attachment in two axes with sufficient range and speed to counter tremor.";
        }
        require actuator.pitchRange >= 15.0 'deg';
        require actuator.rollRange >= 15.0 'deg';
        require actuator.maxAngularSpeed >= 300.0 'deg/s';
    }

    requirement def BatteryRequirement {
        subject battery :> BatteryPack;
        objective {
            doc "The battery pack shall provide at least 1 hour of active stabilization on a full charge.";
        }
        require battery.capacity >= 1.0 'W*h';
    }

    requirement def PowerManagementRequirement {
        subject device :> StabilizingUtensil;
        objective {
            doc "The device shall enter standby when no tremor is detected and return to active stabilization when tremor resumes.";
        }
        require device.controller.stateMachine.supportsStandby == true;
    }

    // ---- Part definitions ----
    part def InertialSensor {
        attribute minDetectableFrequency : FrequencyHz = 0.5 'Hz';
        attribute maxDetectableFrequency : FrequencyHz = 20.0 'Hz';
        attribute maxDetectableAmplitude : DisplacementMM = 50.0 'mm';
        attribute sampleRate : FrequencyHz = 200.0 'Hz';
        attribute mass : MassG = 5.0 'g';
        port tremorOut : TremorDataOut;
        port powerIn : PowerIn;
        satisfy SensingRequirement by self;
    }

    part def StabilizationProcessor {
        attribute maxLatency : TimeS = 0.01 's';
        attribute clockRate : FrequencyHz = 100.0e6 'Hz';
        attribute mass : MassG = 8.0 'g';
        port tremorIn : TremorDataIn;
        port commandOut : CorrectionCommandOut;
        port powerIn : PowerIn;
        port statusIn : BatteryStatusIn;
        satisfy LatencyRequirement by self;

        action def ComputeCorrection {
            in tremor : TremorData;
            out command : CorrectionCommand;
        }
    }

    part def GimbalActuator {
        attribute pitchRange : AngleDeg = 20.0 'deg';
        attribute rollRange : AngleDeg = 20.0 'deg';
        attribute maxAngularSpeed : AngularRateDps = 500.0 'deg/s';
        attribute mass : MassG = 25.0 'g';
        port commandIn : CorrectionCommandIn;
        port powerIn : PowerIn;
        port utensilMount :>> mechanicalInterface;
        satisfy ActuationRequirement by self;

        action def ActuateGimbal {
            in command : CorrectionCommand;
        }
    }

    part def UtensilAttachment {
        attribute kind : String = "spoon";
        attribute mass : MassG = 12.0 'g';
        port mountInterface :>> mechanicalInterface;
    }

    part def BatteryPack {
        attribute capacity : EnergyWh = 2.0 'W*h';
        attribute nominalVoltage : VoltageV = 3.7 'V';
        attribute maxChargeCurrent : CurrentA = 0.5 'A';
        attribute stateOfCharge : Percent = 100.0 '%';
        port powerOut : PowerOut;
        port statusOut : BatteryStatusOut;
        port chargeIn : ChargingIn;
        satisfy BatteryRequirement by self;
    }

    part def Handle {
        attribute mass : MassG = 60.0 'g';
        attribute material : String = "ABS plastic";
        port chargePort : ChargingIn;
    }

    part def StabilizingUtensil {
        attribute tremorCancellationEffectiveness : Percent = 80.0 '%';
        port externalChargePort : ChargingIn;

        part handle : Handle {
            port chargePort : ChargingIn = externalChargePort;
        }

        part inertialSensor : InertialSensor {
            port tremorOut : TremorDataOut;
            port powerIn : PowerIn;
        }

        part processor : StabilizationProcessor {
            port tremorIn : TremorDataIn;
            port commandOut : CorrectionCommandOut;
            port powerIn : PowerIn;
            port statusIn : BatteryStatusIn;
        }

        part gimbalActuator : GimbalActuator {
            port commandIn : CorrectionCommandIn;
            port powerIn : PowerIn;
            port utensilMount;
        }

        part utensilAttachment : UtensilAttachment {
            port mountInterface;
        }

        part battery : BatteryPack {
            port powerOut : PowerOut;
            port statusOut : BatteryStatusOut;
            port chargeIn : ChargingIn;
        }

        part controller : PowerController {
            port statusIn : BatteryStatusIn;
            port powerIn : PowerIn;
            port powerToSensor : PowerOut;
            port powerToProcessor : PowerOut;
            port powerToActuator : PowerOut;
            port powerToBattery : PowerIn;
            attribute stateMachine :>> DeviceStateMachine;
        }

        satisfy StabilizationRequirement by self;
        satisfy PowerManagementRequirement by self;

        // ---- Connections ----
        connection inertialToProcessor connect inertialSensor.tremorOut to processor.tremorIn;
        connection processorToActuator connect processor.commandOut to gimbalActuator.commandIn;
        connection batteryToController connect battery.powerOut to controller.powerIn;
        connection batteryStatusToController connect battery.statusOut to controller.statusIn;
        connection batteryStatusToProcessor connect battery.statusOut to processor.statusIn;
        connection controllerToSensor connect controller.powerToSensor to inertialSensor.powerIn;
        connection controllerToProcessor connect controller.powerToProcessor to processor.powerIn;
        connection controllerToActuator connect controller.powerToActuator to gimbalActuator.powerIn;
        connection chargeToBattery connect handle.chargePort to battery.chargeIn;
        connection mechanicalMount connect gimbalActuator.utensilMount to utensilAttachment.mountInterface;
    }

    part def PowerController {
        attribute lowBatteryThreshold : Percent = 15.0 '%';
        attribute standbyTimeout : TimeS = 5.0 's';
        port statusIn : BatteryStatusIn;
        port powerIn : PowerIn;
        port powerToSensor : PowerOut;
        port powerToProcessor : PowerOut;
        port powerToActuator : PowerOut;
        port powerToBattery : PowerIn;
        attribute stateMachine :>> DeviceStateMachine;
    }

    // ---- State machine ----
    state def DeviceStateMachine {
        entry action { /* initialize subsystems */ }
        attribute supportsStandby : Boolean = true;

        state standby {
            entry action { /* reduce power to sensor only */ }
            accept inertialSensor.tremorOut.tremor
                then activeStabilization;
        }

        state activeStabilization {
            entry action { /* enable processor and gimbal actuator */ }
            do action { /* continuously compute and apply corrections */ }
            accept when (no tremor detected for standbyTimeout)
                then standby;
        }

        state lowBattery {
            entry action { /* alert user, limit actuation */ }
            accept when (battery.chargeIn.chargePower.voltage > 0.0 'V')
                then charging;
        }

        state charging {
            entry action { /* disable actuation, allow charging */ }
            accept when (battery.stateOfCharge >= 95.0 '%')
                then standby;
        }

        transition initial to standby;
        transition standby_to_active
            first standby
            accept inertialSensor.tremorOut.tremor
            then activeStabilization;
        transition active_to_standby
            first activeStabilization
            accept when (no tremor detected for controller.standbyTimeout)
            then standby;
        transition any_to_lowBattery
            accept when (battery.stateOfCharge <= controller.lowBatteryThreshold)
            then lowBattery;
        transition lowBattery_to_charging
            first lowBattery
            accept when (battery.chargeIn.chargePower.voltage > 0.0 'V')
            then charging;
        transition charging_to_standby
            first charging
            accept when (battery.stateOfCharge >= 95.0 '%')
            then standby;
    }
}
