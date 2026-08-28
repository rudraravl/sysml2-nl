package 'Inflatable Habitat System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        value type PressureValue :> Pressure;
        value type VolumeValue :> Volume;
        value type FlowRateValue :> VolumeFlowRate;
        value type TimeValue :> Time;

        item def Air;

        attribute def DeployCommand;
        attribute def StowCommand;
        attribute def EmergencyVentCommand;
        attribute def StartCompressorSignal;
        attribute def StopCompressorSignal;
        attribute def ReverseCompressorSignal;
        attribute def OpenVentSignal;
        attribute def PressureHighAlert;

        port def AirFlowPort {
            in out air : Air;
        }
        port def PressureDataPort {
            out pressure : PressureValue;
            out volume : VolumeValue;
        }
        port def CommandPort {
            in deploy : DeployCommand;
            in stow : StowCommand;
            in vent : EmergencyVentCommand;
        }
        port def ControlSignalPort {
            out startCompressor : StartCompressorSignal;
            out stopCompressor : StopCompressorSignal;
            out reverseCompressor : ReverseCompressorSignal;
            out openVent : OpenVentSignal;
        }

        part def InflatableStructure {
            doc /* Durable, high-strength Kevlar-reinforced polymer inflatable structure. */
            attribute material : String = "Kevlar-reinforced polymer";
            attribute maxVolume : VolumeValue = 200 [m^3];
            attribute maxPressure : PressureValue = 120 [kPa];
            attribute targetPressure : PressureValue = 101 [kPa];
            attribute minPressure : PressureValue = 80 [kPa];
            attribute currentVolume : VolumeValue;
            attribute currentPressure : PressureValue;
            port airIn : ~AirFlowPort;
            port airOut : ~AirFlowPort;
            port sensorData : PressureDataPort;
        }

        part def CompressorUnit {
            doc /* Integrated compressor unit for inflation and deflation. */
            attribute maxFlowRate : FlowRateValue = 1.0 [m^3/s];
            attribute currentFlowRate : FlowRateValue;
            port airOutput : AirFlowPort;
            port airInput : AirFlowPort;
            port controlInput : ~ControlSignalPort;
        }

        part def PressureMonitor {
            doc /* Continuous pressure and volume monitoring system. */
            attribute samplingInterval : TimeValue = 1 [s];
            port senseIn : ~PressureDataPort;
            port pressureData : PressureDataPort;
        }

        part def FlowController {
            doc /* System brain: receives external commands and manages deployment. */
            attribute targetPressure : PressureValue = 101 [kPa];
            attribute minPressure : PressureValue = 80 [kPa];
            attribute maxPressure : PressureValue = 120 [kPa];
            port commands : CommandPort;
            port pressureInput : ~PressureDataPort;
            port controlOutput : ControlSignalPort;
        }

        part def InflatableHabitatSystem {
            doc /* Automated inflatable habitat system for space exploration,
               planetary bases, and rapid-deployment terrestrial shelters. */
            part structure : InflatableStructure;
            part compressor : CompressorUnit;
            part monitor : PressureMonitor;
            part controller : FlowController;

            connect compressor.airOutput to structure.airIn;
            connect structure.airOut to compressor.airInput;
            connect structure.sensorData to monitor.senseIn;
            connect monitor.pressureData to controller.pressureInput;
            connect controller.controlOutput to compressor.controlInput;

            exhibit state habitatStates : HabitatStates;
        }

        action def Inflate;
        action def Deflate;
        action def Vent;
        action def SensePressure { out pressure : PressureValue; }
        action def SenseVolume { out volume : VolumeValue; }
        action def MaintainPressure;

        state def HabitatStates;
    }

    package Usages {
        private import Definitions::*;

        action inflate : Inflate;
        action deflate : Deflate;
        action vent : Vent;
        action sensePressure : SensePressure;
        action senseVolume : SenseVolume;
        action maintainPressure : MaintainPressure;

        part habitatSystem : InflatableHabitatSystem;

        state habitatStates : HabitatStates {
            entry; then stowed;

            state stowed {
                doc /* Compact, safe stowed configuration. */
            }
            accept DeployCommand
                do send new StartCompressorSignal() to habitatSystem.compressor
                then deploying;

            state deploying {
                do sensePressure;
                do inflate;
            }
            accept when sensePressure.pressure >= habitatSystem.structure.targetPressure
                do send new StopCompressorSignal() to habitatSystem.compressor
                then operational;
            accept when sensePressure.pressure > habitatSystem.structure.maxPressure
                do send new OpenVentSignal() to habitatSystem.compressor
                then venting;

            state operational {
                do sensePressure;
                do maintainPressure;
            }
            accept StowCommand
                do send new ReverseCompressorSignal() to habitatSystem.compressor
                then stowing;
            accept EmergencyVentCommand
                do send new OpenVentSignal() to habitatSystem.compressor
                then venting;
            accept when sensePressure.pressure > habitatSystem.structure.maxPressure
                do send new OpenVentSignal() to habitatSystem.compressor
                then venting;

            state stowing {
                do sensePressure;
                do deflate;
            }
            accept when sensePressure.pressure <= habitatSystem.structure.minPressure
                do send new StopCompressorSignal() to habitatSystem.compressor
                then stowed;
            accept EmergencyVentCommand
                do send new OpenVentSignal() to habitatSystem.compressor
                then venting;

            state venting {
                do sensePressure;
                do vent;
            }
            accept when sensePressure.pressure <= habitatSystem.structure.minPressure
                then stowed;
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def DeploymentTimeRequirement {
            doc /* The habitat shall deploy from stowed to operational within the maximum deployment time. */
            attribute maxDeploymentTime : TimeValue = 600 [s];
            subject habitat : InflatableHabitatSystem;
            require {
                habitat.structure.maxVolume / habitat.compressor.maxFlowRate <= maxDeploymentTime;
            }
        }

        requirement def PressureSafetyRequirement {
            doc /* Internal pressure shall remain within safe operating limits at all times. */
            attribute minSafePressure : PressureValue = 80 [kPa];
            attribute maxSafePressure : PressureValue = 120 [kPa];
            subject habitat : InflatableHabitatSystem;
            require {
                habitat.structure.minPressure >= minSafePressure;
            }
            require {
                habitat.structure.maxPressure <= maxSafePressure;
            }
        }

        requirement def VolumeRequirement {
            doc /* The inflatable structure shall hold at least the specified volume when fully deployed. */
            attribute requiredVolume : VolumeValue = 200 [m^3];
            subject habitat : InflatableHabitatSystem;
            require {
                habitat.structure.maxVolume >= requiredVolume;
            }
        }

        requirement def MaterialRequirement {
            doc /* The inflatable structure shall be constructed from a durable, high-strength material. */
            subject habitat : InflatableHabitatSystem;
            require {
                habitat.structure.material == "Kevlar-reinforced polymer";
            }
        }
    }
}
