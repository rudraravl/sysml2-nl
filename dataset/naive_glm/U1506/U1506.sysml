package PrecisionStaticPressureControlSystem {
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value def PressureValue :> Real { unit = 'Pa'; }
    value def FlowRateValue :> Real { unit = 'm3/s'; }
    value def VoltageValue :> Real { unit = 'V'; }
    value def DigitalSignalValue :> Real { unit = 'V'; }
    value def DimensionlessValue :> Real { unit = '1'; }

    attribute targetPressure : PressureValue = 101325.0 [Pa];
    attribute overPressureLimit : PressureValue = 120000.0 [Pa];
    attribute standbyPressureLimit : PressureValue = 5000.0 [Pa];
    attribute startupRampRate : PressureValue = 5000.0 [Pa/s];

    // ===== Item Types =====
    item def Air {
        attribute pressure : PressureValue;
        attribute temperature : Real { unit = 'K'; } = 293.15 [K];
        attribute flowRate : FlowRateValue;
    }

    item def PressurizedAir :> Air {
        attribute regulatedPressure : PressureValue;
    }

    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute active : Boolean;
    }

    item def DigitalSignal {
        attribute value : DigitalSignalValue;
        attribute valid : Boolean;
    }

    item def ControlCommand {
        attribute valvePosition : Real { unit = '1'; } // 0..1
        attribute ventCommand : Boolean;
    }

    // ===== Port Definitions =====
    port def AirInletPort {
        out airIn : Air;
    }

    port def AirOutletPort {
        in airOut : Air;
    }

    port def PressureSignalPort {
        out pressureSignal : ElectricalSignal;
    }

    port def DigitalSignalPort {
        out digitalSignal : DigitalSignal;
    }

    port def ControlCommandPort {
        in command : ControlCommand;
    }

    port def CommandInputPort {
        in startCmd : Boolean;
        in stopCmd : Boolean;
        in setpointCmd : PressureValue;
    }

    port def StatusOutputPort {
        out systemState : String;
        out measuredPressure : PressureValue;
        out alarmActive : Boolean;
    }

    // ===== Requirements =====
    requirement def PressureControlRequirement {
        doc /* The system shall maintain vessel pressure within specified tolerance of target. */
        attribute target : PressureValue;
        attribute tolerance : PressureValue = 500.0 [Pa];
        requirement { 
            subject vesselPressure : PressureValue;
            assert vesselPressure >= target - tolerance and vesselPressure <= target + tolerance;
        }
    }

    requirement def OverPressureSafetyRequirement {
        doc /* The system shall enter alarm state and activate emergency vent if pressure exceeds safety limit. */
        attribute limit : PressureValue;
        requirement {
            subject measuredPressure : PressureValue;
            assert measuredPressure < limit implies noAlarmRequired;
            assert measuredPressure >= limit implies ventRequired;
        }
    }

    requirement def RedundantMeasurementRequirement {
        doc /* The system shall use two static pressure probes for redundancy and accuracy. */
        attribute probeCount : Integer = 2;
        requirement { assert probeCount >= 2; }
    }

    requirement def StartupShutdownRequirement {
        doc /* The system shall execute controlled startup and shutdown sequences. */
        requirement { assert startupSequenceExists; }
        requirement { assert shutdownSequenceExists; }
    }

    // ===== Parts =====

    part def PressureRegulator {
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
        attribute setpoint : PressureValue = targetPressure;
        attribute regulatedFlow : FlowRateValue;

        action regulate {
            in incomingAir : Air;
            out regulatedAir : PressurizedAir;
            // Initial coarse regulation to bring pressure close to setpoint
            if incomingAir.pressure > setpoint then {
                regulatedAir.pressure = setpoint;
                regulatedAir.flowRate = incomingAir.flowRate;
            } else {
                regulatedAir.pressure = incomingAir.pressure;
                regulatedAir.flowRate = incomingAir.flowRate;
            }
        }
    }

    part def PressureVessel {
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
        port probePort1 : AirOutletPort;
        port probePort2 : AirOutletPort;
        port ventPort : AirOutletPort;

        attribute volume : Real { unit = 'm3'; } = 0.5 [m3];
        attribute currentPressure : PressureValue;
        attribute storedAir : PressurizedAir;

        action buffer {
            in incomingAir : PressurizedAir;
            out bufferedAir : PressurizedAir;
            // Smooth out fluctuations
            bufferedAir.pressure = incomingAir.regulatedPressure;
            bufferedAir.flowRate = incomingAir.flowRate;
        }
    }

    part def StaticPressureProbe {
        port sensingPort : AirInletPort;
        port signalPort : PressureSignalPort;

        attribute probeId : String;
        attribute measuredPressure : PressureValue;
        attribute isPrimary : Boolean;

        action sense {
            in ambientAir : Air;
            out pressureSignal : ElectricalSignal;
            // Static pressure measurement unaffected by airflow velocity
            pressureSignal.voltage = ambientAir.pressure / 10000.0 [Pa/V];
            pressureSignal.active = true;
        }
    }

    part def PressureTransmitter {
        port inputPort : PressureSignalPort;
        port outputPort : DigitalSignalPort;

        attribute calibrationFactor : DimensionlessValue = 1.0;
        attribute outputSignal : DigitalSignal;

        action convert {
            in electricalSignal : ElectricalSignal;
            out digitalSignal : DigitalSignal;
            digitalSignal.value = electricalSignal.voltage * 10000.0;
            digitalSignal.valid = electricalSignal.active;
        }
    }

    part def ControlValve {
        port commandPort : ControlCommandPort;
        port inlet : AirInletPort;
        port outlet : AirOutletPort;

        attribute position : Real { unit = '1'; } = 0.0; // 0 closed, 1 open
        attribute maxFlowRate : FlowRateValue = 0.1 [m3/s];

        action modulate {
            in command : ControlCommand;
            in incomingAir : Air;
            out outgoingAir : Air;
            position = command.valvePosition;
            outgoingAir.flowRate = maxFlowRate * position;
            outgoingAir.pressure = incomingAir.pressure;
        }
    }

    part def EmergencyVent {
        port commandPort : ControlCommandPort;
        port ventPort : AirOutletPort;

        attribute isOpen : Boolean = false;
        attribute ventFlowRate : FlowRateValue = 0.2 [m3/s];

        action vent {
            in command : ControlCommand;
            out ventedAir : Air;
            isOpen = command.ventCommand;
            if isOpen then {
                ventedAir.flowRate = ventFlowRate;
            } else {
                ventedAir.flowRate = 0.0 [m3/s];
            }
        }
    }

    part def Controller {
        port primaryInput : DigitalSignalPort;
        port secondaryInput : DigitalSignalPort;
        port valveCommand : ControlCommandPort;
        port ventCommand : ControlCommandPort;
        port commandInput : CommandInputPort;
        port statusOutput : StatusOutputPort;

        attribute measuredPressure : PressureValue;
        attribute secondaryPressure : PressureValue;
        attribute setpoint : PressureValue = targetPressure;
        attribute controlError : PressureValue;
        attribute valvePosition : Real { unit = '1'; } = 0.0;
        attribute ventActive : Boolean = false;
        attribute systemState : String = "standby";
        attribute alarmActive : Boolean = false;

        // PID-like control parameters
        attribute proportionalGain : DimensionlessValue = 0.0001;
        attribute integralGain : DimensionlessValue = 0.00001;
        attribute derivativeGain : DimensionlessValue = 0.0005;
        attribute integralTerm : PressureValue = 0.0 [Pa];
        attribute derivativeTerm : PressureValue = 0.0 [Pa];
        attribute previousError : PressureValue = 0.0 [Pa];

        action computeControl {
            in primarySignal : DigitalSignal;
            in secondarySignal : DigitalSignal;
            out valveCmd : ControlCommand;
            out ventCmd : ControlCommand;

            // Select primary measurement, cross-check with secondary
            if primarySignal.valid then {
                measuredPressure = primarySignal.value;
            } else {
                measuredPressure = secondarySignal.value;
            }

            // Compute error
            controlError = setpoint - measuredPressure;

            // PID computation
            integralTerm = integralTerm + controlError;
            derivativeTerm = controlError - previousError;
            previousError = controlError;

            // Compute valve position
            valvePosition = proportionalGain * controlError + integralGain * integralTerm + derivativeGain * derivativeTerm;

            // Clamp valve position
            if valvePosition > 1.0 then { valvePosition = 1.0; }
            if valvePosition < 0.0 then { valvePosition = 0.0; }

            valveCmd.valvePosition = valvePosition;
            valveCmd.ventCommand = false;

            // Safety check
            if measuredPressure >= overPressureLimit then {
                ventCmd.ventCommand = true;
                ventActive = true;
                alarmActive = true;
            } else {
                ventCmd.ventCommand = false;
                ventActive = false;
            }
        }
    }

    // ===== State Machine for System Operation =====
    state def SystemStateMachine {
        attribute currentPressure : PressureValue;

        state standby {
            entry { 
                systemState = "standby";
                valvePosition = 0.0;
                ventActive = false;
                alarmActive = false;
            }
            do {
                // Monitor for safe unpressurized condition
                assert currentPressure < standbyPressureLimit;
            }
            transition standby_to_startup 
                if commandInput.startCmd == true 
                to startup;
        }

        state startup {
            entry { systemState = "startup"; }
            do {
                // Carefully open valves and build pressure
                valvePosition = valvePosition + 0.01;
                // Ramp pressure toward target
                if currentPressure < targetPressure then {
                    // Continue building pressure
                }
            }
            transition startup_to_operational 
                if currentPressure >= targetPressure - 500.0 [Pa] and currentPressure <= targetPressure + 500.0 [Pa]
                to operational;
            transition startup_to_alarm 
                if currentPressure >= overPressureLimit
                to alarm;
        }

        state operational {
            entry { systemState = "operational"; }
            do {
                // Continuously run control loop to regulate pressure
                computeControl;
            }
            transition operational_to_alarm 
                if currentPressure >= overPressureLimit
                to alarm;
            transition operational_to_shutdown 
                if commandInput.stopCmd == true
                to shutdown;
        }

        state alarm {
            entry { 
                systemState = "alarm";
                alarmActive = true;
                ventActive = true;
            }
            do {
                // Activate emergency vent
                ventActive = true;
                valvePosition = 0.0;
            }
            transition alarm_to_shutdown 
                if currentPressure < overPressureLimit and commandInput.stopCmd == true
                to shutdown;
            transition alarm_to_standby 
                if currentPressure < standbyPressureLimit
                to standby;
        }

        state shutdown {
            entry { systemState = "shutdown"; }
            do {
                // Controlled venting of all pressure
                valvePosition = 0.0;
                ventActive = true;
            }
            transition shutdown_to_standby 
                if currentPressure < standbyPressureLimit
                to standby;
        }
    }

    // ===== Top-level System Assembly =====
    part def PrecisionStaticPressureControlSystem {
        port airSupply : AirInletPort;
        port airOutput : AirOutletPort;
        port operatorCommand : CommandInputPort;
        port systemStatus : StatusOutputPort;

        part regulator : PressureRegulator {
            attribute setpoint = targetPressure;
        }
        part vessel : PressureVessel;
        part primaryProbe : StaticPressureProbe {
            attribute probeId = "P1";
            attribute isPrimary = true;
        }
        part secondaryProbe : StaticPressureProbe {
            attribute probeId = "P2";
            attribute isPrimary = false;
        }
        part transmitter : PressureTransmitter;
        part controller : Controller;
        part controlValve : ControlValve;
        part emergencyVent : EmergencyVent;

        // Internal connections
        connection airSupplyToRegulator : airSupply.airIn to regulator.inlet.airIn;
        connection regulatorToVessel : regulator.outlet.airOut to vessel.inlet.airIn;
        connection vesselToPrimaryProbe : vessel.probePort1.airOut to primaryProbe.sensingPort.airIn;
        connection vesselToSecondaryProbe : vessel.probePort2.airOut to secondaryProbe.sensingPort.airIn;
        connection primaryProbeToTransmitter : primaryProbe.signalPort.pressureSignal to transmitter.inputPort.pressureSignal;
        connection transmitterToController : transmitter.outputPort.digitalSignal to controller.primaryInput.digitalSignal;
        connection secondaryProbeToController : secondaryProbe.signalPort.pressureSignal to controller.secondaryInput.pressureSignal;
        connection controllerToValve : controller.valveCommand.command to controlValve.commandPort.command;
        connection controllerToVent : controller.ventCommand.command to emergencyVent.commandPort.command;
        connection vesselToValve : vessel.outlet.airOut to controlValve.inlet.airIn;
        connection valveToOutput : controlValve.outlet.airOut to airOutput.airOut;
        connection vesselToVent : vessel.ventPort.airOut to emergencyVent.ventPort.airOut;
        connection operatorToController : operatorCommand.startCmd to controller.commandInput.startCmd;
        connection operatorStopToController : operatorCommand.stopCmd to controller.commandInput.stopCmd;
        connection operatorSetpointToController : operatorCommand.setpointCmd to controller.commandInput.setpointCmd;
        connection controllerStatusToOutput : controller.statusOutput.systemState to systemStatus.systemState;

        // State machine behavior
        behavior systemOperation : SystemStateMachine;

        // Requirement satisfaction
        satisfy PressureControlRequirement { 
            target = targetPressure;
            subject vesselPressure = vessel.currentPressure;
        }
        satisfy OverPressureSafetyRequirement {
            limit = overPressureLimit;
            subject measuredPressure = controller.measuredPressure;
        }
        satisfy RedundantMeasurementRequirement;
        satisfy StartupShutdownRequirement;
    }
}
