package EmergencyWarningSystem {
    import ScalarValues::*;

    // ---- Value types with units ----
    item def Voltage :> Real { unit "V"; }
    item def Current :> Real { unit "A"; }
    item def Power :> Real { unit "W"; }
    item def Frequency :> Real {> Real { unit "W"; }
    item def Frequency :> Real { unit "Hz"; }
    item def SoundPressure :> Real { unit "dB"; }
    item def Duration :> Real { unit "s"; }
    item def Resistance :> Real { unit "ohm"; }
    item def ChargeLevel :> Real { unit "ratio"; min 0.0; max 1.0; }

    // ---- Enumerations ----
    enum def Priority { standard; urgent; emergency; }
    enum def SirenTone { off; wail; yelp; piercer; phaser; horn; }
    enum def LightPattern { off; steady; singleFlash; doubleFlash; tripleFlash; rotating; }
    enum def SystemState { off; standby; active; fault; }
    enum def HealthStatus { healthy; degraded; faulted; }
    enum def PowerSource { vehicle; battery; }

    // ---- Item definitions ----
    item def OperatorCommand {
        attribute priority : Priority = standard;
        attribute sirenTone : SirenTone = off;
        attribute lightPattern : LightPattern = off;
        attribute manualOverride : Boolean = false;
    }

    item def SirenInstruction {
        attribute tone : SirenTone = off;
        attribute targetVolume : SoundPressureUnit = 110;
        attribute enabled : Boolean = true;
    }

    item def LightInstruction {
        attribute pattern : LightPattern = off;
        attribute intensity : Real = 1.0;
        attribute enabled : Boolean = true;
    }

    item def SirenSignal {
        attribute waveform : String;
        attribute frequency : FrequencyUnit;
        attribute amplitude : VoltageUnit;
    }

    item def LightDriveSignal {
        attribute pattern : LightPattern;
        attribute driveCurrent : CurrentUnit;
    }

    item def ElectricalPower {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
        attribute source : PowerSource;
    }

    item def DiagnosticStatus {
        attribute health : HealthStatus = healthy;
        attribute batteryCharge : ChargeLevel = 1.0;
        attribute speakerFaultCount : Integer = 0;
        attribute lightFaultCount : Integer = 0;
        attribute timestamp : Duration;
    }

    // ---- Port definitions ----
    port def CommandPort { out item OperatorCommand; }
    port def SirenInstructionPort { out item SirenInstruction; }
    port def LightInstructionPort { out item LightInstruction; }
    port def DiagnosticPort { out item DiagnosticStatus; }
    port def PowerPort { out item ElectricalPower; }
    port def AudioSignalPort { out item SirenSignal; }
    port def LightDrivePort { out item LightDriveSignal; }

    // ---- Control Processor ----
    part def ControlProcessor {
        port commandIn : CommandPort;
        port sirenOut : SirenInstructionPort;
        port lightOut : LightInstructionPort;
        port diagIn : DiagnosticPort;
        port diagOut : DiagnosticPort;
        port powerIn : PowerPort;

        attribute clockFrequency : FrequencyUnit = 16.0e6;
        attribute watchdogTimeout : Duration = 0.5;
        attribute lastCommand : OperatorCommand;
        attribute currentState : SystemState = off;

        action def ProcessCommand {
            in cmd : OperatorCommand;
            out sirenInstr : SirenInstruction;
            out lightInstr : LightInstruction;
            
            if cmd.priority == Priority::emergency {
                sirenInstr.tone = cmd.sirenTone;
                sirenInstr.targetVolume = 118;
                sirenInstr.enabled = true;
                lightInstr.pattern = cmd.lightPattern;
                lightInstr.intensity = 1.0;
                lightInstr.enabled = true;
            } elif cmd.priority == Priority::urgent {
                sirenInstr.tone = cmd.sirenTone;
                sirenInstr.targetVolume = 110;
                sirenInstr.enabled = true;
                lightInstr.pattern = cmd.lightPattern;
                lightInstr.intensity = 0.8;
                lightInstr.enabled = true;
            } else {
                sirenInstr.enabled = false;
                lightInstr.enabled = false;
            }
        }

        action def RunDiagnostics {
            in power : ElectricalPower;
            out status : DiagnosticStatus;
            
            status.timestamp = 0.0;
            if power.voltage < 9.0 {
                status.health = HealthStatus::degraded;
            } else {
                status.health = HealthStatus::healthy;
            }
        }

        state def ControlProcessorBehavior {
            entry action { currentState = SystemState::off; }

            state Off {
                entry action { currentState = SystemState::off; }
                transition to Standby 
                    when commandIn?OperatorCommand[priority != Priority::standard];
            }

            state Standby {
                entry action { currentState = SystemState::standby; }
                do action { RunDiagnostics(power=powerIn.receive(), status=diagOut); }
                transition to Active 
                    when commandIn?OperatorCommand[priority == Priority::emergency or priority == Priority::urgent];
                transition to Off 
                    when commandIn?OperatorCommand[manualOverride == true and priority == Priority::standard];
            }

            state Active {
                entry action { currentState = SystemState::active; }
                do action {
                    ProcessCommand(cmd=commandIn.receive(), 
                                   sirenInstr=sirenOut, 
                                   lightInstr=lightOut);
                    RunDiagnostics(power=powerIn.receive(), status=diagOut);
                }
                transition to Standby 
                    when commandIn?OperatorCommand[priority == Priority::standard];
                transition to Fault 
                    when diagIn?DiagnosticStatus[health == HealthStatus::faulted];
            }

            state Fault {
                entry action { currentState = SystemState::fault; }
                do action { diagOut.send(DiagnosticStatus{health=HealthStatus::faulted}); }
                transition to Off 
                    when commandIn?OperatorCommand[manualOverride == true];
            }
        }

        exhibit state ControlProcessorBehavior;
    }

    // ---- Power Supply Unit ----
    part def PowerSupplyUnit {
        port vehiclePowerIn : PowerPort;
        port conditionedPowerOut : PowerPort;
        port diagOut : DiagnosticPort;

        attribute nominalInputVoltage : VoltageUnit = 12.0;
        attribute nominalOutputVoltage : VoltageUnit = 12.0;
        attribute maxOutputCurrent : CurrentUnit = 40.0;
        attribute batteryCapacity : PowerUnit = 200.0;
        attribute batteryCharge : ChargeLevel = 1.0;
        attribute backupDuration : Duration = 1800.0;
        attribute lowVoltageThreshold : VoltageUnit = 9.0;
        attribute rechargeThreshold : VoltageUnit = 11.0;

        action def ConditionPower {
            in raw : ElectricalPower;
            out conditioned : ElectricalPower;
            
            conditioned.voltage = nominalOutputVoltage;
            conditioned.current = raw.current;
            conditioned.source = raw.source;
        }

        action def DischargeBattery {
            in amount : CurrentUnit;
            out supplied : ElectricalPower;
            
            supplied.voltage = nominalOutputVoltage;
            supplied.current = amount;
            supplied.source = PowerSource::battery;
            batteryCharge = batteryCharge - (amount * 0.0001);
        }

        state def PowerSupplyBehavior {
            state NormalOperation {
                entry action { /* power conditioning active */ }
                do action {
                    ConditionPower(raw=vehiclePowerIn.receive(), 
                                   conditioned=conditionedPowerOut);
                    if batteryCharge < 1.0 {
                        batteryCharge = batteryCharge + 0.001;
                    }
                }
                transition to BatteryBackup 
                    when vehiclePowerIn?ElectricalPower[voltage < lowVoltageThreshold];
            }

            state BatteryBackup {
                entry action { /* switched to battery backup */ }
                do action {
                    DischargeBattery(amount=25.0, supplied=conditionedPowerOut);
                    diagOut.send(DiagnosticStatus{health=HealthStatus::degraded, batteryCharge=batteryCharge});
                }
                transition to NormalOperation 
                    when vehiclePowerIn?ElectricalPower[voltage >= rechargeThreshold];
                transition to PowerLoss 
                    when batteryCharge < 0.05;
            }

            state PowerLoss {
                entry action { 
                    diagOut.send(DiagnosticStatus{health=HealthStatus::faulted, batteryCharge=batteryCharge});
                }
                transition to NormalOperation 
                    when vehiclePowerIn?ElectricalPower[voltage >= rechargeThreshold];
            }
        }

        exhibit state PowerSupplyBehavior;
    }

    // ---- Siren Driver ----
    part def SirenDriver {
        port sirenIn : SirenInstructionPort;
        port audioOut : AudioSignalPort;
        port powerIn : PowerPort;
        port diagOut : DiagnosticPort;

        attribute amplifierPower : PowerUnit = 100.0;
        attribute outputImpedance : Resistance = 4.0;
        attribute channelCount : Integer = 4;
        attribute thermalLimit : PowerUnit = 120.0;
        attribute operational : Boolean = true;

        action def GenerateSirenSignal {
            in instruction : SirenInstruction;
            out signal : SirenSignal;
            
            if instruction.tone == SirenTone::wail {
                signal.waveform = "sine_sweep_low";
                signal.frequency = 800.0;
            } elif instruction.tone == SirenTone::yelp {
                signal.waveform = "fast_sweep";
                signal.frequency = 1200.0;
            } elif instruction.tone == SirenTone::piercer {
                signal.waveform = "steady_high";
                signal.frequency = 2500.0;
            } elif instruction.tone == SirenTone::phaser {
                signal.waveform = "phase_modulated";
                signal.frequency = 1500.0;
            } elif instruction.tone == SirenTone::horn {
                signal.waveform = "square_burst";
                signal.frequency = 440.0;
            } else {
                signal.waveform = "none";
                signal.frequency = 0.0;
            }
            signal.amplitude = 12.0;
        }

        state def SirenDriverBehavior {
            state Idle {
                entry action { operational = true; }
                transition to Generating 
                    when sirenIn?SirenInstruction[enabled == true];
            }

            state Generating {
                do action {
                    GenerateSirenSignal(instruction=sirenIn.receive(), 
                                        signal=audioOut);
                }
                transition to Idle 
                    when sirenIn?SirenInstruction[enabled == false];
                transition to ThermalShutdown 
                    when amplifierPower > thermalLimit;
            }

            state ThermalShutdown {
                entry action { 
                    operational = false;
                    diagOut.send(DiagnosticStatus{health=HealthStatus::faulted});
                }
                transition to Idle 
                    when amplifierPower < (thermalLimit * 0.8);
            }
        }

        exhibit state SirenDriverBehavior;
    }

    // ---- Light Controller ----
    part def LightController {
        port lightIn : LightInstructionPort;
        port driveOut : LightDrivePort;
        port powerIn : PowerPort;
        port diagOut : DiagnosticPort;

        attribute channelCount : Integer = 6;
        attribute maxDriveCurrent : CurrentUnit = 5.0;
        attribute perChannelPower : PowerUnit = 25.0;
        attribute operational : Boolean = true;

        action def ComputeLightDrive {
            in instruction : LightInstruction;
            out drive : LightDriveSignal;
            
            drive.pattern = instruction.pattern;
            drive.driveCurrent = maxDriveCurrent * instruction.intensity;
        }

        state def LightControllerBehavior {
            state Off {
                entry action { operational = true; }
                transition to Flashing 
                    when lightIn?LightInstruction[enabled == true];
            }

            state Flashing {
                do action {
                    ComputeLightDrive(instruction=lightIn.receive(), 
                                      drive=driveOut);
                }
                transition to Off 
                    when lightIn?LightInstruction[enabled == false];
                transition to Fault 
                    when powerIn?ElectricalPower[voltage < 9.0];
            }

            state Fault {
                entry action { 
                    operational = false;
                    diagOut.send(DiagnosticStatus{health=HealthStatus::faulted});
                }
                transition to Off 
                    when powerIn?ElectricalPower[voltage >= 11.0];
            }
        }

        exhibit state LightControllerBehavior;
    }

    // ---- Speaker Array ----
    part def SpeakerArray {
        port audioIn : AudioSignalPort;
        port diagOut : DiagnosticPort;

        attribute speakerCount : Integer = 1;
        attribute maxOutput : SoundPressureUnit = 123.0;
        attribute nominalImpedance : Resistance = 11.0;
        attribute powerHandling : PowerUnit = 100.0;
        attribute mountingPosition : String;
        attribute operational : Boolean = true;

        action def ProduceSound {
            in signal : SirenSignal;
            
            if signal.amplitude > 0.0 and operational {
                /* acoustic output generated */
            }
        }

        state def SpeakerBehavior {
            state Silent {
                transition to Sounding 
                    when audioIn?SirenSignal[amplitude > 0.0];
            }
            state Sounding {
                do action { ProduceSound(signal=audioIn.receive()); }
                transition to Silent 
                    when audioIn?SirenSignal[amplitude == 0.0];
                transition to Damaged 
                    when audioIn?SirenSignal[amplitude > 15.0];
            }
            state Damaged {
                entry action { 
                    operational = false;
                    diagOut.send(DiagnosticStatus{health=HealthStatus::faulted});
                }
            }
        }

        exhibit state SpeakerBehavior;
    }

    // ---- LED Light Head ----
    part def LEDLightHead {
        port driveIn : LightDrivePort;
        port diagOut : DiagnosticPort;

        attribute ledCount : Integer = 8;
        attribute color : String;
        attribute maxPower : PowerUnit = 25.0;
        attribute forwardVoltage : VoltageUnit = 12.0;
        attribute operational : Boolean = true;
        attribute totalOnTime : Duration = 0.0;
        attribute ratedLifetime : Duration = 50000.0;

        action def EmitLight {
            in drive : LightDriveSignal;
            
            if drive.driveCurrent > 0.0 and operational {
                totalOnTime = totalOnTime + 0.1;
            }
        }

        state def LEDBehavior {
            state Dark {
                transition to Illuminated 
                    when driveIn?LightDriveSignal[driveCurrent > 0.0];
            }
            state Illuminated {
                do action { EmitLight(drive=driveIn.receive()); }
                transition to Dark 
                    when driveIn?LightDriveSignal[driveCurrent == 0.0];
                transition to Failed 
                    when totalOnTime > ratedLifetime;
            }
            state Failed {
                entry action { 
                    operational = false;
                    diagOut.send(DiagnosticStatus{health=HealthStatus::faulted});
                }
            }
        }

        exhibit state LEDBehavior;
    }

    // ---- Top-level Emergency Warning System ----
    part def EmergencyWarningSystem {
        part controlProcessor : ControlProcessor;
        part powerSupply : PowerSupplyUnit;
        part sirenDriver : SirenDriver;
        part lightController : LightController;
        part speakers : SpeakerArray[4] {
            part speakerFrontLeft : SpeakerArray { mountingPosition = "frontLeft"; }
            part speakerFrontRight : SpeakerArray { mountingPosition = "frontRight"; }
            part speakerRearLeft : SpeakerArray { mountingPosition = "rearLeft"; }
            part speakerRearRight : SpeakerArray { mountingPosition = "rearRight"; }
        }
        part lightHeads : LEDLightHead[6] {
            part lightFrontLeft : LEDLightHead { color = "blue"; }
            part lightFrontRight : LEDLightHead { color = "blue"; }
            part lightCenterLeft : LEDLightHead { color = "red"; }
            part lightCenterRight : LEDLightHead { color = "red"; }
            part lightRearLeft : LEDLightHead { color = "blue"; }
            part lightRearRight : LEDLightHead { color = "blue"; }
        }

        // Power distribution
        connect powerSupply.conditionedPowerOut to controlProcessor.powerIn;
        connect powerSupply.conditionedPowerOut to sirenDriver.powerIn;
        connect powerSupply.conditionedPowerOut to lightController.powerIn;

        // Command and instruction flow
        connect controlProcessor.sirenOut to sirenDriver.sirenIn;
        connect controlProcessor.lightOut to lightController.lightIn;

        // Diagnostic feedback
        connect powerSupply.diagOut to controlProcessor.diagIn;
        connect sirenDriver.diagOut to controlProcessor.diagIn;
        connect lightController.diagOut to controlProcessor.diagIn;

        // Audio signal distribution to speakers
        connect sirenDriver.audioOut to speakers.audioIn;

        // Light drive signal distribution to LED heads
        connect lightController.driveOut to lightHeads.driveIn;
    }

    // ---- Requirements ----
    requirement def AudibleAlertRequirement {
        doc "The system shall produce audible warning signals of at least 110 dB at 1 m."
        attribute minSoundPressure : SoundPressureUnit = 110.0;
        attribute maxResponseTime : Duration = 0.5;
        satisfy by EmergencyWarningSystem.speakers;
    }

    requirement def VisualAlertRequirement {
        doc "The system shall provide coordinated visual alerts via six LED light heads with selectable patterns."
        attribute minLightHeadCount : Integer = 6;
        attribute supportedPatterns : Integer = 5;
        satisfy by EmergencyWarningSystem.lightHeads;
    }

    requirement def PowerBackupRequirement {
        doc "The system shall operate for at least 1800 s on battery backup if primary power fails."
        attribute minBackupDuration : Duration = 1800.0;
        attribute minBatteryCapacity : PowerUnit = 200.0;
        satisfy by EmergencyWarningSystem.powerSupply;
    }

    requirement def DiagnosticRequirement {
        doc "The system shall continuously monitor operational health and report diagnostic status."
        attribute maxDiagnosticLatency : Duration = 1.0;
        satisfy by EmergencyWarningSystem.controlProcessor;
    }

    requirement def CoordinationRequirement {
        doc "The Control Processor shall coordinate siren and light outputs based on operator command priority."
        attribute maxCommandLatency : Duration = 0.2;
        satisfy by EmergencyWarningSystem.controlProcessor;
    }

    requirement def SirenToneRequirement {
        doc "The Siren Driver shall support wail, yelp, piercer, phaser, and horn tones."
        attribute requiredToneCount : Integer = 5;
        satisfy by EmergencyWarningSystem.sirenDriver;
    }

    requirement def ReliabilityRequirement {
        doc "All components shall report faults and continue degraded operation when possible."
        attribute minAvailability : Real = 0.999;
        satisfy by EmergencyWarningSystem;
    }
}
