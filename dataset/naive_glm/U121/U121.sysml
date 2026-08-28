package MedicalInfusionPumpSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----

    value type FlowRate specializes Real {
        unit 'mL/h';
    }

    value type Volume specializes Real {
        unit 'mL';
    }

    value type Pressure specializes Real {
        unit 'kPa';
    }

    value type Percentage specializes Real {
        unit '%';
    }

    // ---- Item Types ----

    item def TherapeuticSubstance {
        attribute name : String;
        attribute concentration : Real;
        attribute prescribedVolume : Volume;
        attribute prescribedFlowRate : FlowRate;
    }

    item def AirBubble {
        attribute volume : Volume;
    }

    // ---- Port Definitions ----

    port def FluidPort {
        out item substance : TherapeuticSubstance[0..*];
        out item air : AirBubble[0..*];
        attribute pressure : Pressure;
    }

    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
        out attribute measuredFlowRate : FlowRate;
    }

    port def SensorDataPort {
        out attribute flowRate : FlowRate;
        out attribute remainingVolume : Volume;
        out attribute reservoirInstalled : Boolean;
        out attribute airDetected : Boolean;
    }

    port def AlarmPort {
        out attribute alarmActive : Boolean;
        out attribute alarmType : String;
        out attribute alarmMessage : String;
    }

    // ---- Requirements ----

    requirement def SafeDeliveryRequirement {
        subject : MedicalInfusionPumpSystem;
        objective {
            doc "The infusion pump shall deliver therapeutic substances at a controlled rate within safe limits."
        }
    }

    requirement def FlowAccuracyRequirement {
        attribute tolerance : Percentage = 5;
        subject : FlowController;
        objective {
            doc "The flow controller shall maintain the actual flow rate within +/-5% of the prescribed flow rate."
        }
    }

    requirement def SafetyMonitoringRequirement {
        attribute minSafeFlowRate : FlowRate = 0.1;
        attribute maxSafeFlowRate : FlowRate = 500.0;
        attribute lowReservoirThreshold : Volume = 2.0;
        subject : SafetyMonitor;
        objective {
            doc "The safety monitor shall trigger an alarm and halt delivery if flow rate is outside safe limits or reservoir is nearly empty."
        }
    }

    requirement def StateTransitionRequirement {
        subject : MedicalInfusionPumpSystem;
        objective {
            doc "The system shall transition through standby, loading, priming, infusing, completed, and alarm states as specified."
        }
    }

    // ---- Component Definitions ----

    part def SubstanceReservoir {
        attribute capacity : Volume = 300;
        attribute currentVolume : Volume;
        attribute substanceType : TherapeuticSubstance;
        port fluidOut : FluidPort;
        port sensorOut : SensorDataPort;

        action def UpdateVolume {
            in deltaVolume : Volume;
            then UpdateSensorOutput;
        }

        action def UpdateSensorOutput {
            out remainingVolume : Volume := currentVolume;
            out reservoirInstalled : Boolean := true;
        }

        exhibit state reservoirState {
            entry;
            state Empty;
            state PartiallyFilled;
            state Full;
            transition Empty_to_PartiallyFilled
                first Empty
                if currentVolume > 0
                then PartiallyFilled;
            transition PartiallyFilled_to_Full
                first PartiallyFilled
                if currentVolume >= capacity
                then Full;
            transition PartiallyFilled_to_Empty
                first PartiallyFilled
                if currentVolume <= 0
                then Empty;
        }
    }

    part def InfusionPump {
        attribute maxFlowRate : FlowRate = 1000.0;
        attribute currentSpeed : FlowRate;
        attribute isRunning : Boolean = false;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlIn : ControlPort;

        action def StartPump {
            in targetFlowRate : FlowRate;
            then SetSpeed;
        }

        action def SetSpeed {
            in targetFlowRate : FlowRate;
            if targetFlowRate <= maxFlowRate {
                currentSpeed := targetFlowRate;
                isRunning := true;
            }
        }

        action def StopPump {
            currentSpeed := 0;
            isRunning := false;
        }

        exhibit state pumpOperation {
            state Stopped;
            state Running;
            transition Stopped_to_Running
                first Stopped
                if controlIn.command == "start"
                then Running;
            transition Running_to_Stopped
                first Running
                if controlIn.command == "stop"
                then Stopped;
        }
    }

    part def FlowController {
        attribute prescribedFlowRate : FlowRate;
        attribute actualFlowRate : FlowRate;
        attribute tolerance : Percentage = 5;
        port controlOut : ControlPort;
        port sensorIn : SensorDataPort;
        port alarmOut : AlarmPort;

        action def AdjustPumpSpeed {
            in measuredFlowRate : FlowRate;
            in targetFlowRate : FlowRate;
            attribute error : FlowRate;
            attribute correction : FlowRate;
            then SendControlCommand;
        }

        action def SendControlCommand {
            out command : String;
            out targetSpeed : FlowRate;
        }

        action def MonitorFlow {
            in measuredFlowRate : FlowRate;
            in targetFlowRate : FlowRate;
            attribute deviation : Percentage;
            if abs(measuredFlowRate - targetFlowRate) / targetFlowRate * 100 > tolerance {
                triggerAlarm("flowRateDeviation");
            }
        }

        action def triggerAlarm {
            in alarmType : String;
            alarmOut.alarmActive := true;
            alarmOut.alarmType := alarmType;
        }
    }

    part def SafetyMonitor {
        attribute minSafeFlowRate : FlowRate = 0.1;
        attribute maxSafeFlowRate : FlowRate = 500.0;
        attribute lowReservoirThreshold : Volume = 2.0;
        attribute alarmActive : Boolean = false;
        port sensorIn : SensorDataPort;
        port alarmOut : AlarmPort;

        action def CheckFlowRate {
            in flowRate : FlowRate;
            if flowRate < minSafeFlowRate {
                triggerAlarm("lowFlowRate", "Flow rate below safe minimum");
            }
            if flowRate > maxSafeFlowRate {
                triggerAlarm("highFlowRate", "Flow rate above safe maximum");
            }
        }

        action def CheckReservoirLevel {
            in remainingVolume : Volume;
            if remainingVolume <= lowReservoirThreshold {
                triggerAlarm("lowReservoir", "Reservoir nearly empty");
            }
        }

        action def CheckForAir {
            in airDetected : Boolean;
            if airDetected {
                triggerAlarm("airInLine", "Air bubble detected in delivery path");
            }
        }

        action def triggerAlarm {
            in alarmType : String;
            in alarmMessage : String;
            alarmActive := true;
            alarmOut.alarmActive := true;
            alarmOut.alarmType := alarmType;
            alarmOut.alarmMessage := alarmMessage;
        }

        action def ClearAlarm {
            alarmActive := false;
            alarmOut.alarmActive := false;
        }

        exhibit state monitorState {
            state Monitoring;
            state AlarmTriggered;
            transition Monitoring_to_AlarmTriggered
                first Monitoring
                if alarmActive == true
                then AlarmTriggered;
            transition AlarmTriggered_to_Monitoring
                first AlarmTriggered
                if alarmActive == false
                then Monitoring;
        }
    }

    part def PatientInterface {
        attribute tubeLength : Real = 150;
        attribute cannulaDiameter : Real = 0.3;
        port fluidIn : FluidPort;
        port patientConnection : FluidPort;
        attribute deliveryPressure : Pressure;

        action def DeliverToPatient {
            in substance : TherapeuticSubstance;
            out deliveredVolume : Volume;
        }

        action def PrimeTubing {
            out airCleared : Boolean;
            attribute primingComplete : Boolean = false;
            then DeliverToPatient;
        }
    }

    // ---- Top-level System ----

    part def MedicalInfusionPumpSystem {
        attribute systemID : String;
        attribute prescribedTherapy : TherapeuticSubstance;
        attribute totalDeliveredVolume : Volume = 0;

        satisfy SafeDeliveryRequirement;
        satisfy StateTransitionRequirement;

        part reservoir : SubstanceReservoir {
            attribute capacity : Volume = 300;
        }

        part pump : InfusionPump {
            attribute maxFlowRate : FlowRate = 1000.0;
        }

        part controller : FlowController {
            attribute prescribedFlowRate : FlowRate;
            satisfy FlowAccuracyRequirement;
        }

        part monitor : SafetyMonitor {
            satisfy SafetyMonitoringRequirement;
        }

        part patientInterface : PatientInterface;

        // Connections
        connection reservoirToPump connect reservoir.fluidOut to pump.fluidIn {
            item substance flows from reservoir.fluidOut.substance to pump.fluidIn.substance;
            item air flows from reservoir.fluidOut.air to pump.fluidIn.air;
        }

        connection pumpToPatient connect pump.fluidOut to patientInterface.fluidIn {
            item substance flows from pump.fluidOut.substance to patientInterface.fluidIn.substance;
        }

        connection patientToPatient connect patientInterface.patientConnection to patientInterface.patientConnection;

        connection controllerToPump connect controller.controlOut to pump.controlIn {
            attribute command flows from controller.controlOut.command to pump.controlIn.command;
        }

        connection reservoirToController connect reservoir.sensorOut to controller.sensorIn {
            attribute remainingVolume flows from reservoir.sensorOut.remainingVolume to controller.sensorIn.remainingVolume;
            attribute reservoirInstalled flows from reservoir.sensorOut.reservoirInstalled to controller.sensorIn.reservoirInstalled;
        }

        connection reservoirToMonitor connect reservoir.sensorOut to monitor.sensorIn {
            attribute remainingVolume flows from reservoir.sensorOut.remainingVolume to monitor.sensorIn.remainingVolume;
            attribute reservoirInstalled flows from reservoir.sensorOut.reservoirInstalled to monitor.sensorIn.reservoirInstalled;
        }

        connection controllerToMonitor connect controller.alarmOut to monitor.alarmOut;

        // System-level state machine
        exhibit state systemState {
            entry {
                totalDeliveredVolume := 0;
            }

            state standby {
                entry {
                    pump.StopPump();
                }
            }

            state loading {
                entry {
                    // Reservoir installation detected
                }
            }

            state priming {
                entry {
                    patientInterface.PrimeTubing();
                }
            }

            state infusing {
                entry {
                    pump.StartPump(prescribedTherapy.prescribedFlowRate);
                }
                do {
                    controller.AdjustPumpSpeed(controller.sensorIn.flowRate, prescribedTherapy.prescribedFlowRate);
                    monitor.CheckFlowRate(controller.sensorIn.flowRate);
                    monitor.CheckReservoirLevel(controller.sensorIn.remainingVolume);
                    monitor.CheckForAir(controller.sensorIn.airDetected);
                }
            }

            state paused {
                entry {
                    pump.StopPump();
                }
            }

            state completed {
                entry {
                    pump.StopPump();
                }
            }

            state alarm {
                entry {
                    pump.StopPump();
                    monitor.alarmOut.alarmActive := true;
                }
            }

            transition standby_to_loading
                first standby
                if reservoir.sensorOut.reservoirInstalled == true
                then loading;

            transition loading_to_priming
                first loading
                if reservoir.sensorOut.reservoirInstalled == true
                then priming;

            transition priming_to_infusing
                first priming
                if patientInterface.PrimeTubing.airCleared == true
                then infusing;

            transition infusing_to_paused
                first infusing
                if controller.controlOut.command == "pause"
                then paused;

            transition paused_to_infusing
                first paused
                if controller.controlOut.command == "resume"
                then infusing;

            transition infusing_to_completed
                first infusing
                if totalDeliveredVolume >= prescribedTherapy.prescribedVolume
                then completed;

            transition infusing_to_alarm
                first infusing
                if monitor.alarmOut.alarmActive == true
                then alarm;

            transition paused_to_alarm
                first paused
                if monitor.alarmOut.alarmActive == true
                then alarm;

            transition priming_to_alarm
                first priming
                if monitor.alarmOut.alarmActive == true
                then alarm;

            transition alarm_to_standby
                first alarm
                if monitor.alarmActive == false
                then standby;

            transition completed_to_standby
                first completed
                if controller.controlOut.command == "reset"
                then standby;
        }

        action def SystemStartup {
            then InitializeComponents;
            then VerifyReservoir;
            then EnterStandby;
        }

        action def InitializeComponents {
            pump.isRunning := false;
            controller.actualFlowRate := 0;
            monitor.alarmActive := false;
        }

        action def VerifyReservoir {
            if reservoir.sensorOut.reservoirInstalled == false {
                monitor.triggerAlarm("noReservoir", "No reservoir installed");
            }
        }

        action def EnterStandby {
            // System enters standby state
        }

        action def DeliverTherapy {
            in substance : TherapeuticSubstance;
            attribute deliveredVolume : Volume = 0;
            then StartDelivery;
            then MonitorDelivery;
            then CompleteDelivery;
        }

        action def StartDelivery {
            pump.StartPump(substance.prescribedFlowRate);
        }

        action def MonitorDelivery {
            while deliveredVolume < substance.prescribedVolume {
                controller.AdjustPumpSpeed(controller.sensorIn.flowRate, substance.prescribedFlowRate);
                monitor.CheckFlowRate(controller.sensorIn.flowRate);
                monitor.CheckReservoirLevel(controller.sensorIn.remainingVolume);
                deliveredVolume := deliveredVolume + controller.sensorIn.flowRate * 1.0;
                totalDeliveredVolume := totalDeliveredVolume + controller.sensorIn.flowRate * 1.0;
            }
        }

        action def CompleteDelivery {
            pump.StopPump();
        }
    }

    // ---- System Instance ----

    part infusionPumpInstance : MedicalInfusionPumpSystem {
        attribute systemID := "IP-001";
        attribute prescribedTherapy := TherapeuticSubstance {
            name := "Insulin";
            concentration := 100.0;
            prescribedVolume := 50.0;
            prescribedFlowRate := 5.0;
        };
    }

}
