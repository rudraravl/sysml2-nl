package ElectromagneticCloakingSystem {
    import ISQ::SpaceTime::*;
    import SI::*;

    // ===== Value Types =====
    def FrequencyValue :> Real { unit "Hz"; }
    def AmplitudeValue :> Real { unit "V/m"; }
    def AngleValue :> Real { unit "deg"; }
    def PermittivityValue :> Real { unit "F/m"; }
    def PermeabilityValue :> Real { unit "H/m"; }
    def RefractiveIndexValue :> Real { unit "1"; }
    def PowerValue :> Real { unit "W"; }
    def VoltageValue :> Real { unit "V"; }
    def ResponseTimeValue :> Real { unit "us"; }
    def DistortionValue :> Real { unit "1"; }
    def CellIdValue :> Integer;
    def LayerIdValue :> Integer;

    // ===== Item Definitions =====
    item def ElectromagneticWave {
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
        attribute angleOfApproach : AngleValue;
    }

    item def RadarPulse :> ElectromagneticWave;

    item def SensorData {
        attribute detectedWave : ElectromagneticWave;
        attribute timestamp : TimeValue;
    }

    item def CellCommand {
        attribute cellId : CellIdValue;
        attribute targetPermittivity : PermittivityValue;
        attribute targetPermeability : PermeabilityValue;
    }

    item def LayerCommand {
        attribute layerId : LayerIdValue;
        attribute cellCommands : CellCommand[64];
    }

    item def CloakCommandSet {
        attribute layerCommands : LayerCommand[4];
    }

    item def VerificationData {
        attribute residualDistortion : DistortionValue;
        attribute outputWave : ElectromagneticWave;
        attribute timestamp : TimeValue;
    }

    // ===== Port Definitions =====
    port def WaveInputPort {
        attribute incomingWave : ElectromagneticWave;
    }

    port def WaveOutputPort {
        attribute outgoingWave : ElectromagneticWave;
    }

    port def SensorDataPort {
        attribute data : SensorData;
    }

    port def CommandPort {
        attribute command : CloakCommandSet;
    }

    port def VerificationPort {
        attribute verification : VerificationData;
    }

    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
    }

    // ===== Requirements =====
    requirement def CloakingRequirement {
        doc "The system shall make a cloaked object invisible to electromagnetic detection systems.";
        attribute maxDistortion : DistortionValue = 0.01;
        attribute maxResponseTime : ResponseTimeValue = 5.0;
    }

    requirement def SensingRequirement {
        doc "The wave sensor shall detect incoming wave frequency, amplitude, and angle of approach.";
        attribute frequencyResolution : FrequencyValue = 1.0e6;
        attribute angularResolution : AngleValue = 1.0;
    }

    requirement def ProcessingRequirement {
        doc "The control processor shall calculate metamaterial cell adjustments for all 256 cells within the response time.";
        attribute maxComputationTime : ResponseTimeValue = 2.0;
    }

    requirement def ModulationRequirement {
        doc "Each metamaterial cell shall dynamically adjust permittivity and permeability to guide waves around the object.";
        attribute permittivityRange : PermittivityValue[0..*] = (0.1, 100.0);
        attribute permeabilityRange : PermeabilityValue[0..*] = (0.1, 100.0);
    }

    requirement def VerificationRequirement {
        doc "The system shall verify cloaking effectiveness and optimize in real-time.";
        attribute verificationCycleTime : ResponseTimeValue = 1.0;
    }

    requirement def PowerRequirement {
        doc "The power supply shall provide stable regulated power to the processor and metamaterial layers.";
        attribute nominalVoltage : VoltageValue = 12.0;
        attribute maxPower : PowerValue = 500.0;
    }

    // ===== Part Definitions =====

    part def MetamaterialCell {
        attribute cellId : CellIdValue;
        attribute currentPermittivity : PermittivityValue;
        attribute currentPermeability : PermeabilityValue;
        attribute refractiveIndex : RefractiveIndexValue;

        port commandIn : CommandPort;
        port waveIn : WaveInputPort;
        port waveOut : WaveOutputPort;

        action def AdjustProperties {
            in targetPermittivity : PermittivityValue;
            in targetPermeability : PermeabilityValue;
            out newPermittivity : PermittivityValue;
            out newPermeability : PermeabilityValue;
        }

        action def PropagateWave {
            in incomingWave : ElectromagneticWave;
            in localRefractiveIndex : RefractiveIndexValue;
            outgoingWave : ElectromagneticWave;
        }

        exhibit state CellBehavior {
            entry; exit;
            state idle;
            state adjusting;
            state propagating;
            transition idle to adjusting when commandIn.received;
            transition adjusting to propagating when AdjustProperties.completed;
            transition propagating to idle when PropagateWave.completed;
        }
    }

    part def MetamaterialLayer {
        attribute layerId : LayerIdValue;
        attribute layerOrder : Integer;
        part cells : MetamaterialCell[64];

        port layerCommandIn : CommandPort;
        port layerWaveIn : WaveInputPort;
        port layerWaveOut : WaveOutputPort;

        connection def CellWaveRouting {
            port from cells[1].waveOut;
            port to cells[2].waveIn;
        }

        action def DistributeCommands {
            in command : LayerCommand;
            out cellCommands : CellCommand[64];
        }

        action def PropagateThroughLayer {
            in incomingWave : ElectromagneticWave;
            out outgoingWave : ElectromagneticWave;
        }
    }

    part def MetamaterialShell {
        part layer1 : MetamaterialLayer {
            attribute layerId : LayerIdValue = 1;
            attribute layerOrder : Integer = 1;
        }
        part layer2 : MetamaterialLayer {
            attribute layerId : LayerIdValue = 2;
            attribute layerOrder : Integer = 2;
        }
        part layer3 : MetamaterialLayer {
            attribute layerId : LayerIdValue = 3;
            attribute layerOrder : Integer = 3;
        }
        part layer4 : MetamaterialLayer {
            attribute layerId : LayerIdValue = 4;
            attribute layerOrder : Integer = 4;
        }

        port shellWaveIn : WaveInputPort;
        port shellWaveOut : WaveOutputPort;
        port shellCommandIn : CommandPort;

        connection def LayerWavePassage {
            port from shellWaveIn to layer1.layerWaveIn;
            port from layer1.layerWaveOut to layer2.layerWaveIn;
            port from layer2.layerWaveOut to layer3.layerWaveIn;
            port from layer3.layerWaveOut to layer4.layerWaveIn;
            port from layer4.layerWaveOut to shellWaveOut;
        }

        connection def LayerCommandDistribution {
            port from shellCommandIn to layer1.layerCommandIn;
            port from shellCommandIn to layer2.layerCommandIn;
            port from shellCommandIn to layer3.layerCommandIn;
            port from shellCommandIn to layer4.layerCommandIn;
        }
    }

    part def WaveSensor {
        port waveProbe : WaveInputPort;
        port dataOut : SensorDataPort;

        attribute detectionResolution : FrequencyValue = 1.0e6;
        attribute angularResolution : AngleValue = 1.0;

        action def SenseWave {
            in incomingWave : ElectromagneticWave;
            out sensorData : SensorData;
        }

        action def MonitorEnvironment {
            doc "Continuously monitor the electromagnetic environment for incoming waves.";
            in waveProbe : WaveInputPort;
            out dataOut : SensorDataPort;
        }
    }

    part def VerificationSensor {
        port waveProbe : WaveInputPort;
        port verificationOut : VerificationPort;

        action def MeasureOutput {
            in outputWave : ElectromagneticWave;
            out verification : VerificationData;
        }

        action def DetectDistortion {
            in outputWave : ElectromagneticWave;
            out distortion : DistortionValue;
        }
    }

    part def ControlProcessor {
        port sensorDataIn : SensorDataPort;
        port commandOut : CommandPort;
        port verificationIn : VerificationPort;

        attribute maxComputationTime : ResponseTimeValue = 2.0;
        attribute optimizationThreshold : DistortionValue = 0.01;

        action def CalculateRefractiveIndexPattern {
            in sensorData : SensorData;
            out refractivePattern : RefractiveIndexValue[256];
        }

        action def GenerateCellCommands {
            in refractivePattern : RefractiveIndexValue[256];
            out commandSet : CloakCommandSet;
        }

        action def OptimizeSettings {
            in verification : VerificationData;
            in currentCommandSet : CloakCommandSet;
            out refinedCommandSet : CloakCommandSet;
        }

        action def ProcessSensorData {
            in sensorData : SensorData;
            out commandSet : CloakCommandSet;
        }

        action def VerifyAndOptimize {
            in verification : VerificationData;
            in currentCommandSet : CloakCommandSet;
            out refinedCommandSet : CloakCommandSet;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 12.0;
        attribute maxPower : PowerValue = 500.0;
        attribute currentLoad : PowerValue;

        port processorPower : PowerPort;
        port shellPower : PowerPort;

        action def RegulatePower {
            in demand : PowerValue;
            out suppliedVoltage : VoltageValue;
            out suppliedPower : PowerValue;
        }

        exhibit state PowerState {
            entry; exit;
            state off;
            state on;
            transition off to on when RegulatePower.activated;
            transition on to off when RegulatePower.deactivated;
        }
    }

    // ===== Main System =====
    part def CloakingSystem {
        attribute systemId : String;
        attribute maxResponseTime : ResponseTimeValue = 5.0;

        part powerSupply : PowerSupply;
        part waveSensor : WaveSensor;
        part verificationSensor : VerificationSensor;
        part processor : ControlProcessor;
        part shell : MetamaterialShell;

        port externalWaveIn : WaveInputPort;
        port externalWaveOut : WaveOutputPort;

        // Connections
        connection def PowerDistribution {
            port from powerSupply.processorPower to processor;
            port from powerSupply.shellPower to shell;
        }

        connection def SensorToProcessor {
            port from waveSensor.dataOut to processor.sensorDataIn;
        }

        connection def ProcessorToShell {
            port from processor.commandOut to shell.shellCommandIn;
        }

        connection def ExternalToSensor {
            port from externalWaveIn to waveSensor.waveProbe;
        }

        connection def ExternalToShell {
            port from externalWaveIn to shell.shellWaveIn;
        }

        connection def ShellToVerification {
            port from shell.shellWaveOut to verificationSensor.waveProbe;
        }

        connection def VerificationToProcessor {
            port from verificationSensor.verificationOut to processor.verificationIn;
        }

        connection def ShellOutput {
            port from shell.shellWaveOut to externalWaveOut;
        }

        // Main operational state machine
        exhibit state SystemStateMachine {
            entry; exit;

            state powerOff {
                entry;
                doc "System is fully powered down.";
            }
            state initialization {
                entry;
                doc "System initializes and performs self-calibration.";
            }
            state standby {
                entry;
                doc "System is ready and waiting for activation.";
            }
            state activeCloaking {
                entry;
                doc "System is actively cloaking, running the sense-process-modulate-verify loop.";
            }
            state faultState {
                entry;
                doc "System has encountered a fault and is in a safe state.";
            }

            transition powerOff to initialization
                when powerSupply.RegulatePower.activated;

            transition initialization to standby
                when initialization.selfCalibrationComplete;

            transition standby to activeCloaking
                when activationCommand.received;

            transition activeCloaking to standby
                when deactivationCommand.received;

            transition activeCloaking to faultState
                when faultDetected;

            transition faultState to standby
                when faultResolved;

            transition standby to powerOff
                when shutdownCommand.received;

            transition activeCloaking to powerOff
                when shutdownCommand.received;
        }

        // Continuous cloaking loop action
        action def CloakingLoop {
            doc "The continuous sense-process-modulate-verify optimization loop.";

            action sense : WaveSensor.MonitorEnvironment {
                in waveProbe : WaveInputPort;
                out dataOut : SensorDataPort;
            }

            action process : ControlProcessor.ProcessSensorData {
                in sensorData : SensorData;
                out commandSet : CloakCommandSet;
            }

            action modulate : MetamaterialShell {
                in commandSet : CloakCommandSet;
                in incomingWave : ElectromagneticWave;
                out outgoingWave : ElectromagneticWave;
            }

            action verify : VerificationSensor.MeasureOutput {
                in outputWave : ElectromagneticWave;
                out verification : VerificationData;
            }

            action optimize : ControlProcessor.VerifyAndOptimize {
                in verification : VerificationData;
                in currentCommandSet : CloakCommandSet;
                out refinedCommandSet : CloakCommandSet;
            }

            flow from sense.dataOut to process.sensorData;
            flow from process.commandSet to modulate.commandSet;
            flow from modulate.outgoingWave to verify.outputWave;
            flow from verify.verification to optimize.verification;
            flow from optimize.refinedCommandSet to process.commandSet;

            // Loop control
            decision cloakingEffective {
                if optimize.refinedCommandSet.distortion < processor.optimizationThreshold
                    then continueCloaking
                    else recalibrate;
            }

            continueCloaking then sense;
            recalibrate then process;
        }

        // Requirements satisfaction
        satisfy CloakingRequirement {
            attribute maxDistortion = verificationSensor.DetectDistortion.distortion;
            attribute maxResponseTime = maxResponseTime;
        }

        satisfy SensingRequirement by waveSensor;
        satisfy ProcessingRequirement by processor;
        satisfy ModulationRequirement by shell;
        satisfy VerificationRequirement by verificationSensor;
        satisfy PowerRequirement by powerSupply;
    }

    // ===== System-level requirement allocation =====
    requirement def SystemRequirements {
        requirement cloaking : CloakingRequirement;
        requirement sensing : SensingRequirement;
        requirement processing : ProcessingRequirement;
        requirement modulation : ModulationRequirement;
        requirement verification : VerificationRequirement;
        requirement power : PowerRequirement;
    }
}
