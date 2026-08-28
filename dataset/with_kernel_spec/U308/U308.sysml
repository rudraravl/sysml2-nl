package MichaabSystem {
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        public import ISQ::*;
        public import ScalarValues::*;

        attribute def FillCommand;
        attribute def StartMillingCommand;
        attribute def StopMillingCommand;
        attribute def StartIrrigationCommand;
        attribute def StopIrrigationCommand;
        attribute def MaintenanceCommand;
        attribute def CompleteMaintenanceCommand;
        attribute def WaterLevelFull;

        item def Water;
        item def Grain;
        item def Flour;

        item def MechanicalPower {
            attribute torque : Real;
            attribute rotationalSpeed : Real;
        }

        item def GateCommand {
            attribute position : Real;
        }

        item def WaterLevelSignal {
            attribute value : Real;
        }

        item def WaterQualitySignal {
            attribute suitability : Real;
        }

        port def WaterPort {
            out item water : Water;
        }

        port def MechanicalPowerPort {
            out item power : MechanicalPower;
        }

        port def GrainPort {
            out item grain : Grain;
        }

        port def FlourPort {
            out item flour : Flour;
        }

        port def GateCommandPort {
            out item command : GateCommand;
        }

        port def WaterLevelPort {
            out item signal : WaterLevelSignal;
        }

        port def WaterQualityPort {
            out item signal : WaterQualitySignal;
        }

        action def GenerateMechanicalPower {
            in water : Water;
            out power : MechanicalPower;
        }

        action def GrindGrain {
            in power : MechanicalPower;
            in grain : Grain;
            out flour : Flour;
        }

        action def RegulateFlow {
            in waterLevel : Real;
            in waterQuality : Real;
            out mainGatePosition : Real;
            out irrigationGatePosition : Real;
        }

        action def CloseAllGates;

        part def UpperReservoir {
            attribute waterLevel :> ISQ::length;
            attribute capacity :> ISQ::volume;
            port waterOutPort : WaterPort;
            port waterLevelOutPort : WaterLevelPort;
            constraint { waterLevel <= capacity }
        }

        part def LowerReservoir {
            attribute waterLevel :> ISQ::length;
            port waterInPort : ~WaterPort;
        }

        part def DistributionChannel {
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
        }

        part def ControlGate {
            attribute position : Real;
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
            port commandInPort : ~GateCommandPort;
            constraint { position >= 0.0 and position <= 1.0 }
        }

        part def SecondaryChannel {
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
        }

        part def WaterWheel {
            attribute rotationalSpeed : Real;
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
            port powerOutPort : MechanicalPowerPort;
            perform action generatePower : GenerateMechanicalPower {
                in water = waterInPort.water;
                out power = powerOutPort.power;
            }
        }

        part def Millstone;

        part def MillingMechanism {
            port powerInPort : ~MechanicalPowerPort;
            port grainInPort : ~GrainPort;
            port flourOutPort : FlourPort;
            part upperMillstone : Millstone;
            part lowerMillstone : Millstone;
            perform action grindGrain : GrindGrain {
                in power = powerInPort.power;
                in grain = grainInPort.grain;
                out flour = flourOutPort.flour;
            }
        }

        part def GrainHopper {
            attribute storedGrain :> ISQ::mass;
            port grainOutPort : GrainPort;
        }

        part def FlourStore {
            attribute storedFlour :> ISQ::mass;
            port flourInPort : ~FlourPort;
        }

        part def IrrigationGate {
            attribute position : Real;
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
            port commandInPort : ~GateCommandPort;
            constraint { position >= 0.0 and position <= 1.0 }
        }

        part def IrrigationChannel {
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
        }

        part def IrrigationOutlet {
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
            port waterQualityOutPort : WaterQualityPort;
        }

        part def IrrigatedField {
            attribute area :> ISQ::area;
            port waterInPort : ~WaterPort;
        }

        part def MichaabController {
            port waterLevelInPort : ~WaterLevelPort;
            port waterQualityInPort : ~WaterQualityPort;
            port mainGateCmdOutPort : GateCommandPort;
            port irrigationGateCmdOutPort : GateCommandPort;
        }

        part def Michaab {
            attribute minOperationalWaterLevel :> ISQ::length = 1.5;
            attribute waterQualityThreshold : Real = 0.7;

            part upperReservoir : UpperReservoir;
            part distributionChannel : DistributionChannel;
            part mainGate : ControlGate;
            part secondaryChannel : SecondaryChannel;
            part waterWheel : WaterWheel;
            part millingMechanism : MillingMechanism;
            part grainHopper : GrainHopper;
            part flourStore : FlourStore;
            part lowerReservoir : LowerReservoir;
            part irrigationGate : IrrigationGate;
            part irrigationChannel : IrrigationChannel;
            part irrigationOutlet : IrrigationOutlet;
            part irrigatedField : IrrigatedField;
            part controller : MichaabController;

            perform action regulateFlow : RegulateFlow {
                in waterLevel = upperReservoir.waterLevel;
                in waterQuality = controller.waterQualityInPort.signal.suitability;
                out mainGatePosition = controller.mainGateCmdOutPort.command.position;
                out irrigationGatePosition = controller.irrigationGateCmdOutPort.command.position;
            }

            perform action closeAllGates : CloseAllGates;

            flow of water : Water
                from upperReservoir.waterOutPort.water to distributionChannel.waterInPort.water;
            flow of water : Water
                from distributionChannel.waterOutPort.water to mainGate.waterInPort.water;
            flow of water : Water
                from mainGate.waterOutPort.water to secondaryChannel.waterInPort.water;
            flow of water : Water
                from secondaryChannel.waterOutPort.water to waterWheel.waterInPort.water;
            flow of water : Water
                from waterWheel.waterOutPort.water to lowerReservoir.waterInPort.water;
            flow of water : Water
                from mainGate.waterOutPort.water to irrigationGate.waterInPort.water;
            flow of water : Water
                from irrigationGate.waterOutPort.water to irrigationChannel.waterInPort.water;
            flow of water : Water
                from irrigationChannel.waterOutPort.water to irrigationOutlet.waterInPort.water;
            flow of water : Water
                from irrigationOutlet.waterOutPort.water to irrigatedField.waterInPort.water;

            flow of power : MechanicalPower
                from waterWheel.powerOutPort.power to millingMechanism.powerInPort.power;
            flow of grain : Grain
                from grainHopper.grainOutPort.grain to millingMechanism.grainInPort.grain;
            flow of flour : Flour
                from millingMechanism.flourOutPort.flour to flourStore.flourInPort.flour;

            flow of command : GateCommand
                from controller.mainGateCmdOutPort.command to mainGate.commandInPort.command;
            flow of command : GateCommand
                from controller.irrigationGateCmdOutPort.command to irrigationGate.commandInPort.command;
            flow of signal : WaterLevelSignal
                from upperReservoir.waterLevelOutPort.signal to controller.waterLevelInPort.signal;
            flow of signal : WaterQualitySignal
                from irrigationOutlet.waterQualityOutPort.signal to controller.waterQualityInPort.signal;

            constraint {
                waterQualityThreshold > 0.0 and waterQualityThreshold < 1.0
            }
            constraint {
                controller.waterQualityInPort.signal.suitability < waterQualityThreshold
                implies irrigationGate.position <= 0.3
            }

            exhibit state michaabStates parallel {
                state operationalMode {
                    entry; then idle;

                    state idle;
                    accept FillCommand then filling;
                    accept StartMillingCommand
                        if upperReservoir.waterLevel >= minOperationalWaterLevel
                        then milling;
                    accept StartIrrigationCommand
                        if upperReservoir.waterLevel >= minOperationalWaterLevel
                        then irrigation;
                    accept MaintenanceCommand then maintenance;

                    state filling;
                    accept WaterLevelFull then idle;
                    accept StartMillingCommand
                        if upperReservoir.waterLevel >= minOperationalWaterLevel
                        then milling;
                    accept StartIrrigationCommand
                        if upperReservoir.waterLevel >= minOperationalWaterLevel
                        then irrigation;
                    accept MaintenanceCommand then maintenance;

                    state milling {
                        do millingMechanism.grindGrain;
                    }
                    accept StopMillingCommand then idle;
                    accept MaintenanceCommand then maintenance;

                    state irrigation;
                    accept StopIrrigationCommand then idle;
                    accept MaintenanceCommand then maintenance;

                    state maintenance {
                        entry closeAllGates;
                    }
                    accept CompleteMaintenanceCommand then idle;
                }

                state automatedControl {
                    entry; then monitoring;

                    state monitoring {
                        do regulateFlow;
                    }
                }
            }
        }

        requirement def ReservoirCapacityRequirement {
            doc /* The upper reservoir shall store sufficient water to support both milling and irrigation. */
            attribute minCapacity :> ISQ::volume;
        }

        requirement def MillingPerformanceRequirement {
            doc /* The water wheel shall provide sufficient mechanical power to drive the millstones. */
        }

        requirement def IrrigationQualityRequirement {
            doc /* Irrigation flow shall be reduced when water quality is unsuitable for crops. */
        }

        requirement def GravityPoweredRequirement {
            doc /* The system shall operate solely on gravitational potential energy of stored water. */
        }

        requirement def DualPurposeRequirement {
            doc /* The system shall simultaneously or selectively support grain milling and agricultural irrigation. */
        }
    }

    package Usages {
        private import Definitions::*;
        private import ISQ::*;

        part michaab : Michaab;

        satisfy ReservoirCapacityRequirement by michaab;
        satisfy MillingPerformanceRequirement by michaab;
        satisfy IrrigationQualityRequirement by michaab;
        satisfy GravityPoweredRequirement by michaab;
        satisfy DualPurposeRequirement by michaab;
    }
}
