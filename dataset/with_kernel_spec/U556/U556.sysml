package 'Roundabout PlayPump System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Water;

        port def WaterInPort {
            in item water : Water;
        }
        port def WaterOutPort {
            out item water : Water;
        }
        port def TorquePort {
            out item torque : TorqueValue;
        }

        interface def TorqueInterface {
            end sourcePort : TorquePort;
            end targetPort : ~TorquePort;
        }

        action def PlayOnRoundabout {
            out torque : TorqueValue;
        }

        action def PumpWater {
            in waterIn : Water;
            in torque : TorqueValue;
            out waterOut : Water;
        }

        part def ChildrensRoundabout {
            attribute diameter : LengthValue;
            attribute numberOfSeats : Integer;
            attribute mass : MassValue;
            attribute inMotion : Boolean = false;
            port torqueOut : TorquePort;
            perform action play : PlayOnRoundabout {
                out torque = torqueOut.torque;
            }
        }

        part def PositiveDisplacementPump {
            attribute efficiency : Real;
            attribute isPumping : Boolean = false;
            port torqueIn : ~TorquePort;
            port waterInPort : WaterInPort;
            port waterOutPort : WaterOutPort;
            perform action pumpWater : PumpWater {
                in waterIn = waterInPort.water;
                in torque = torqueIn.torque;
                out waterOut = waterOutPort.water;
            }
            state machine pumpState {
                state standby { initial; }
                state active;
                transition from standby to active when isPumping;
                transition from active to standby when not isPumping;
            }
        }

        part def Borehole {
            attribute depth : LengthValue;
            port waterOutPort : WaterOutPort;
        }

        part def Pipe {
            attribute length : LengthValue;
            attribute material : String;
            port waterInPort : WaterInPort;
            port waterOutPort : WaterOutPort;
        }

        part def StorageTank {
            attribute capacity : VolumeValue;
            attribute elevation : LengthValue;
            attribute currentVolume : VolumeValue;
            attribute isFilling : Boolean = false;
            attribute isDispensing : Boolean = false;
            port waterInPort : WaterInPort;
            port waterOutPort : WaterOutPort;

            state machine tankState {
                state empty { initial; }
                state filling;
                state full;
                state dispensing;
                transition from empty to filling when isFilling;
                transition from filling to full when currentVolume >= capacity;
                transition from full to dispensing when isDispensing;
                transition from dispensing to empty when currentVolume <= 0 [L];
                transition from dispensing to filling when isFilling and currentVolume < capacity;
            }
        }

        part def RoundaboutPlayPump {
            part roundabout : ChildrensRoundabout;
            part pump : PositiveDisplacementPump;
            part borehole : Borehole;
            part risingMain : Pipe;
            part deliveryPipe : Pipe;
            part storageTank : StorageTank;

            interface : TorqueInterface connect
                sourcePort ::> roundabout.torqueOut to
                targetPort ::> pump.torqueIn;

            flow of water1 : Water from borehole.waterOutPort.water to risingMain.waterInPort.water;
            flow of water2 : Water from risingMain.waterOutPort.water to pump.waterInPort.water;
            flow of water3 : Water from pump.waterOutPort.water to deliveryPipe.waterInPort.water;
            flow of water4 : Water from deliveryPipe.waterOutPort.water to storageTank.waterInPort.water;

            state machine systemState {
                state standby { initial; }
                state active;
                transition from standby to active when roundabout.inMotion;
                transition from active to standby when not roundabout.inMotion;
            }
        }
    }

    package Usages {
        public import Definitions::*;

        part communitySystem : RoundaboutPlayPump {
            part roundabout : ChildrensRoundabout {
                attribute :>> diameter = 3.5 [m];
                attribute :>> numberOfSeats = 8;
                attribute :>> mass = 500 [kg];
            }
            part pump : PositiveDisplacementPump {
                attribute :>> efficiency = 0.85;
            }
            part borehole : Borehole {
                attribute :>> depth = 40 [m];
            }
            part risingMain : Pipe {
                attribute :>> length = 40 [m];
                attribute :>> material = "PVC";
            }
            part deliveryPipe : Pipe {
                attribute :>> length = 2 [m];
                attribute :>> material = "PVC";
            }
            part storageTank : StorageTank {
                attribute :>> capacity = 2500 [L];
                attribute :>> elevation = 7 [m];
                attribute :>> currentVolume = 0 [L];
            }
        }
    }

    package Requirements {
        public import Definitions::*;
        public import Usages::*;

        requirement def <'1'> PumpEfficiencyRequirement {
            doc /* The positive displacement pump shall have an efficiency of at least 80%. */
            attribute efficiencyActual : Real;
            attribute efficiencyMinimum : Real = 0.80;
            require constraint { efficiencyActual >= efficiencyMinimum }
        }

        requirement def <'2'> WaterLiftingCapabilityRequirement {
            doc /* The system shall lift water from a depth of at least 40 m. */
            attribute liftDepthActual : LengthValue;
            attribute liftDepthRequired : LengthValue = 40 [m];
            require constraint { liftDepthActual >= liftDepthRequired }
        }

        requirement def <'3'> StorageCapacityRequirement {
            doc /* The storage tank shall hold at least 2500 L of water. */
            attribute capacityActual : VolumeValue;
            attribute capacityRequired : VolumeValue = 2500 [L];
            require constraint { capacityActual >= capacityRequired }
        }

        requirement def <'4'> RoundaboutSafetyDimensionsRequirement {
            doc /* The roundabout shall be exactly 3.5 m in diameter and have exactly 8 seats for safe play. */
            attribute diameterActual : LengthValue;
            attribute diameterRequired : LengthValue = 3.5 [m];
            attribute seatsActual : Integer;
            attribute seatsRequired : Integer = 8;
            require constraint { diameterActual == diameterRequired && seatsActual == seatsRequired }
        }

        requirement <'1.1'> pumpEff1 : PumpEfficiencyRequirement {
            subject pump :>> Usages::communitySystem.pump;
            attribute :>> efficiencyActual = pump.efficiency;
        }

        requirement <'2.1'> pumpLift1 : WaterLiftingCapabilityRequirement {
            subject borehole :>> Usages::communitySystem.borehole;
            attribute :>> liftDepthActual = borehole.depth;
        }

        requirement <'3.1'> tank1 : StorageCapacityRequirement {
            subject storageTank :>> Usages::communitySystem.storageTank;
            attribute :>> capacityActual = storageTank.capacity;
        }

        requirement <'4.1'> roundabout1 : RoundaboutSafetyDimensionsRequirement {
            subject roundabout :>> Usages::communitySystem.roundabout;
            attribute :>> diameterActual = roundabout.diameter;
            attribute :>> seatsActual = roundabout.numberOfSeats;
        }

        satisfy pumpEff1 by communitySystem.pump;
        satisfy pumpLift1 by communitySystem.borehole;
        satisfy tank1 by communitySystem.storageTank;
        satisfy roundabout1 by communitySystem.roundabout;
    }
}
