package InflatableHabitatSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value def Pressure :> Real { attribute unit : String = "Pa"; }
    value def Volume :> Real { attribute unit : String = "m3"; }
    value def FlowRate :> Real { attribute unit : String = "m3/s"; }
    value def Mass :> Real { attribute unit : String = "kg"; }
    value def Area :> Real { attribute unit : String = "m2"; }
    value def Duration :> Real { attribute unit : String = "s"; }
    value def Temperature :> Real { attribute unit : String = "K"; }
    value def Power :> Real { attribute unit : String = "W"; }

    // ===== Item Types =====
    item def Air {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def DeploymentCommand {
        attribute commandKind : String;
    }

    item def PressureReading {
        attribute pressure : Pressure;
        attribute volume : Volume;
        attribute timestamp : Duration;
    }

    item def ControlSignal {
        attribute signalKind : String;
        attribute targetFlowRate : FlowRate;
    }

    item def AlarmEvent {
        attribute alarmType : String;
        attribute severity : Integer;
    }

    // ===== Port Definitions =====
    port def AirPort {
        out item airOut : Air;
        in item airIn : Air;
        attribute flowRate : FlowRate;
    }

    port def PressureDataOutPort {
        out item reading : PressureReading;
    }

    port def PressureDataInPort {
        in item reading : PressureReading;
    }

    port def CommandInPort {
        in item cmd : DeploymentCommand;
    }

    port def ControlSignalOutPort {
        out item signal : ControlSignal;
    }

    port def ControlSignalInPort {
        in item signal : ControlSignal;
    }

    port def AlarmOutPort {
        out item alarm : AlarmEvent;
    }

    port def AlarmInPort {
        in item alarm : AlarmEvent;
    }

    // ===== Connection Definitions =====
    connection def AirFlowConnection {
        end source : AirPort;
        end target : AirPort;
        flow of Air from source::airOut to target::airIn;
    }

    connection def PressureDataConnection {
        end source : PressureDataOutPort;
        end target : PressureDataInPort;
        flow of PressureReading from source::reading to target::reading;
    }

    connection def ControlSignalConnection {
        end source : ControlSignalOutPort;
        end target : ControlSignalInPort;
        flow of ControlSignal from source::signal to target::signal;
    }

    connection def CommandFlowConnection {
        end source : CommandInPort;
        end target : CommandInPort;
        flow of DeploymentCommand from source::cmd to target::cmd;
    }

    connection def AlarmConnection {
        end source : AlarmOutPort;
        end target : AlarmInPort;
        flow of AlarmEvent from source::alarm to target::alarm;
    }

    // ===== Requirements =====
    requirement def HabitatStructuralRequirement {
        doc "The inflatable structure must maintain structural integrity under operational pressure.";
        attribute maxOperationalPressure : Pressure = 101325;
        attribute minBurstPressure : Pressure = 405300;
        attribute targetVolume : Volume = 200;
        subject structure : InflatableStructure;
        require structure.burstPressure >= minBurstPressure
            and structure.nominalVolume >= targetVolume;
    }

    requirement def DeploymentTimeRequirement {
        doc "The habitat must deploy from stowed to operational within a specified time.";
        attribute maxDeploymentTime : Duration = 600;
        subject system : InflatableHabitat;
        require system.deploymentTime <= maxDeploymentTime;
    }

    requirement def PressureSafetyRequirement {
        doc "Internal pressure must never exceed the emergency threshold.";
        attribute emergencyVentThreshold : Pressure = 121590;
        subject monitor : PressureMonitoringSystem;
        require monitor.currentPressure <= emergencyVentThreshold;
    }

    requirement def BreathableAtmosphereRequirement {
        doc "The habitat must maintain a breathable atmosphere during operational state.";
        attribute minOperationalPressure : Pressure = 90000;
        attribute maxOperationalPressure : Pressure = 101325;
        subject system : InflatableHabitat;
        require system.internalPressure >= minOperationalPressure
            and system.internalPressure <= maxOperationalPressure;
    }

    requirement def CompressorFlowRequirement {
        doc "The compressor must deliver sufficient airflow to meet deployment time targets.";
        attribute minRequiredFlowRate : FlowRate = 0.34;
        subject compressor : CompressorUnit;
        require compressor.maxFlowRate >= minRequiredFlowRate;
    }

    requirement def MonitoringAccuracyRequirement {
        doc "Pressure monitoring must meet minimum accuracy and sampling rate.";
        attribute minSamplingRate : Real = 5.0;
        attribute maxErrorFraction : Real = 0.01;
        subject monitor : PressureMonitoringSystem;
        require monitor.samplingRate >= minSamplingRate
            and (monitor.accuracy / 100.0) <= maxErrorFraction;
    }

    // ===== Part Definitions =====

    part def InflatableStructure {
        attribute material : String = "Kevlar-reinforced polymer";
        attribute nominalVolume : Volume = 200;
        attribute stowedVolume : Volume = 2.0;
        attribute burstPressure : Pressure = 405300;
        attribute fabricThickness : Real = 5.0;
        attribute currentVolume : Volume = 2.0;
        attribute currentPressure : Pressure = 0.0;
        attribute isDeployed : Boolean = false;

        port airPort : AirPort;

        action expand {
            doc "Expand the structure as air flows in.";
            in item air : Air;
            then assign currentVolume = currentVolume + 0.01;
            then assign currentPressure = currentPressure + 50.0;
            then assign isDeployed = (currentVolume >= nominalVolume);
        }

        action contract {
            doc "Contract the structure as air is removed.";
            out item air : Air;
            then assign currentVolume = currentVolume - 0.01;
            then assign currentPressure = currentPressure - 50.0;
            then assign isDeployed = false;
        }

        action emergencyVent {
            doc "Rapidly vent all air from the structure.";
            out item air : Air;
            then assign currentVolume = stowedVolume;
            then assign currentPressure = 0.0;
            then assign isDeployed = false;
        }
    }

    part def CompressorUnit {
        attribute maxFlowRate : FlowRate = 0.5;
        attribute maxPressure : Pressure = 150000;
        attribute powerConsumption : Power = 2000;
        attribute currentFlowRate : FlowRate = 0.0;
        attribute isRunning : Boolean = false;
        attribute mode : String = "idle";

        port intakePort : AirPort;
        port outputPort : AirPort;
        port controlPort : ControlSignalInPort;

        action inflate {
            doc "Supply air to inflate the structure at the commanded flow rate.";
            in item signal : ControlSignal;
            out item air : Air;
            then assign currentFlowRate = signal.targetFlowRate;
            then assign mode = "inflate";
            then assign isRunning = true;
        }

        action deflate {
            doc "Extract air from the structure to deflate it.";
            in item signal : ControlSignal;
            out item air : Air;
            then assign currentFlowRate = signal.targetFlowRate;
            then assign mode = "deflate";
            then assign isRunning = true;
        }

        action vent {
            doc "Rapidly vent air to the environment for emergency depressurization.";
            in item signal : ControlSignal;
            out item air : Air;
            then assign currentFlowRate = maxFlowRate;
            then assign mode = "vent";
            then assign isRunning = false;
        }

        action stop {
            doc "Stop all compressor operations and return to idle.";
            then assign currentFlowRate = 0.0;
            then assign mode = "idle";
            then assign isRunning = false;
        }
    }

    part def PressureMonitoringSystem {
        attribute samplingRate : Real = 10.0;
        attribute currentPressure : Pressure = 0.0;
        attribute currentVolume : Volume = 0.0;
        attribute pressureRange : Pressure = 200000;
        attribute accuracy : Real = 0.5;
        attribute alarmThreshold : Pressure = 121590;
        attribute lowPressureThreshold : Pressure = 50000;

        port sensorDataPort : PressureDataOutPort;
        port alarmPort : AlarmOutPort;

        action readSensors {
            doc "Continuously read internal pressure and volume from the structure.";
            out item reading : PressureReading;
            then assign reading.pressure = currentPressure;
            then assign reading.volume = currentVolume;
        }

        action checkLimits {
            doc "Check if pressure is within safe limits and emit alarms if needed.";
            in item reading : PressureReading;
            out item alarm : AlarmEvent;

            if (reading.pressure >= alarmThreshold) {
                assign alarm.alarmType = "overpressure";
                assign alarm.severity = 2;
            }
            if (reading.pressure <= lowPressureThreshold) {
                assign alarm.alarmType = "underpressure";
                assign alarm.severity = 1;
            }
        }

        action monitorLoop {
            doc "Continuous monitoring loop that reads sensors and checks limits.";
            action read : readSensors;
            action check : checkLimits;
            flow of PressureReading from read.reading to check.reading;
            then read;
        }
    }

    part def FlowController {
        attribute targetPressure : Pressure = 101325;
        attribute emergencyVentThreshold : Pressure = 121590;
        attribute minSafePressure : Pressure = 90000;
        attribute deploymentTime : Duration = 0.0;
        attribute currentCommand : String = "none";

        port commandPort : CommandInPort;
        port pressureDataPort : PressureDataInPort;
        port controlSignalPort : ControlSignalOutPort;
        port alarmInPort : AlarmInPort;

        state def ControllerStateMachine {
            state stowed {
                entry { assign currentCommand = "none"; }
                on commandPort.cmd[commandKind == "deploy"] transition to deploying;
            }

            state deploying {
                entry {
                    assign deploymentTime = 0.0;
                    send ControlSignal{signalKind="inflate", targetFlowRate=0.5} via controlSignalPort;
                }
                do {
                    assign deploymentTime = deploymentTime + 1.0;
                }
                on pressureDataPort.reading[pressure >= targetPressure] transition to operational;
                on pressureDataPort.reading[pressure >= emergencyVentThreshold] transition to venting;
                on alarmInPort.alarm[alarmType == "overpressure"] transition to venting;
                on commandPort.cmd[commandKind == "stow"] transition to stowing;
            }

            state operational {
                entry {
                    send ControlSignal{signalKind="idle", targetFlowRate=0.0} via controlSignalPort;
                }
                do {
                    if (pressureDataPort.reading.pressure < minSafePressure) {
                        send ControlSignal{signalKind="inflate", targetFlowRate=0.1} via controlSignalPort;
                    }
                }
                on commandPort.cmd[commandKind == "stow"] transition to stowing;
                on pressureDataPort.reading[pressure >= emergencyVentThreshold] transition to venting;
                on commandPort.cmd[commandKind == "emergency_vent"] transition to venting;
                on alarmInPort.alarm[alarmType == "overpressure"] transition to venting;
            }

            state stowing {
                entry {
                    send ControlSignal{signalKind="deflate", targetFlowRate=0.3} via controlSignalPort;
                }
                do {
                    assign deploymentTime = deploymentTime + 1.0;
                }
                on pressureDataPort.reading[pressure <= 0.0] transition to stowed;
                on commandPort.cmd[commandKind == "emergency_vent"] transition to venting;
            }

            state venting {
                entry {
                    send ControlSignal{signalKind="vent", targetFlowRate=0.5} via controlSignalPort;
                }
                do {
                    assign deploymentTime = deploymentTime + 1.0;
                }
                on pressureDataPort.reading[pressure <= 0.0] transition to stowed;
            }
        }

        exhibit state behavior : ControllerStateMachine;
    }

    // ===== Top-level System =====
    part def InflatableHabitat {
        attribute systemId : String = "IHS-001";
        attribute internalPressure : Pressure = 0.0;
        attribute deploymentTime : Duration = 0.0;
        attribute maxDeploymentTime : Duration = 600;
        attribute systemState : String = "stowed";

        part inflatableStructure : InflatableStructure {
            attribute material = "Kevlar-reinforced polymer";
            attribute nominalVolume = 200;
            attribute burstPressure = 405300;
        }

        part compressor : CompressorUnit {
            attribute maxFlowRate = 0.5;
            attribute maxPressure = 150000;
            attribute powerConsumption = 2000;
        }

        part pressureMonitor : PressureMonitoringSystem {
            attribute samplingRate = 10.0;
            attribute alarmThreshold = 121590;
            attribute lowPressureThreshold = 50000;
        }

        part flowController : FlowController {
            attribute targetPressure = 101325;
            attribute emergencyVentThreshold = 121590;
            attribute minSafePressure = 90000;
        }

        // External ports
        port externalCommandPort : CommandInPort;
        port systemAlarmPort : AlarmOutPort;

        // Internal connections
        connection : CommandFlowConnection from externalCommandPort to flowController.commandPort;

        connection : ControlSignalConnection from flowController.controlSignalPort to compressor.controlPort;

        connection : AirFlowConnection from compressor.outputPort to inflatableStructure.airPort;

        connection : AirFlowConnection from inflatableStructure.airPort to compressor.intakePort;

        connection : PressureDataConnection from pressureMonitor.sensorDataPort to flowController.pressureDataPort;

        connection : AlarmConnection from pressureMonitor.alarmPort to flowController.alarmInPort;

        connection : AlarmConnection from pressureMonitor.alarmPort to systemAlarmPort;

        // Requirement satisfaction
        satisfy HabitatStructuralRequirement by inflatableStructure;
        satisfy DeploymentTimeRequirement by self;
        satisfy PressureSafetyRequirement by pressureMonitor;
        satisfy BreathableAtmosphereRequirement by self;
        satisfy CompressorFlowRequirement by compressor;
        satisfy MonitoringAccuracyRequirement by pressureMonitor;
    }
}
