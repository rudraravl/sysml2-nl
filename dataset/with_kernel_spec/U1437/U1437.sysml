package APIPlan53BSealSupportSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;

    package Definitions {
        item def BarrierFluid {
            attribute density : Real;
            attribute viscosity : Real;
        }
        item def Gas;
        item def ProcessFluid;

        attribute def PressureValue :> ISQ::pressure;
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def VolumeValue :> ISQ::volume;
        attribute def FlowRateValue :> ISQ::volume flow rate;

        port def BarrierFluidPort {
            in item fluidIn : BarrierFluid;
            out item fluidOut : BarrierFluid;
            attribute pressure : PressureValue;
            attribute temperature : TemperatureValue;
        }

        port def SignalPort {
            out attribute pressureReading : PressureValue;
            out attribute temperatureReading : TemperatureValue;
            out attribute levelReading : VolumeValue;
            in attribute command : String;
        }

        interface def SignalInterface {
            end reservoirEnd : SignalPort;
            end panelEnd : ~SignalPort;
        }

        action def CirculateBarrierFluid {
            in fluidIn : BarrierFluid;
            out fluidOut : BarrierFluid;
        }

        state def MonitoringStates {
            state Normal;
            state LowLevelAlarm;
            state HighTemperatureAlarm;
            state LowPressureAlarm;
            state EmergencyShutdown;
            transition from Normal to LowLevelAlarm guard { currentLevel < lowLevelSetpoint };
            transition from Normal to HighTemperatureAlarm guard { currentTemperature > highTemperatureSetpoint };
            transition from Normal to LowPressureAlarm guard { currentPressure < lowPressureSetpoint };
            transition from LowLevelAlarm to EmergencyShutdown guard { currentLevel < criticalLowLevelSetpoint };
            transition from HighTemperatureAlarm to EmergencyShutdown guard { currentTemperature > criticalHighTemperatureSetpoint };
            transition from LowPressureAlarm to EmergencyShutdown guard { currentPressure < criticalLowPressureSetpoint };
            transition from EmergencyShutdown to Normal guard { resetRequested };
        }

        part def PressurizedReservoir {
            port fluidSupplyPort : BarrierFluidPort;
            port fluidReturnPort : ~BarrierFluidPort;
            port instrumentationPort : SignalPort;
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute operatingPressure : PressureValue;
            attribute preChargePressure : PressureValue;
            item barrierFluid : BarrierFluid;
            part bladderAccumulator {
                item preChargeGas : Gas;
                attribute preCharge : PressureValue;
                attribute currentGasPressure : PressureValue;
            }
            assert constraint {
                operatingPressure >= preChargePressure
            }
        }

        part def CirculationPump {
            port suctionPort : ~BarrierFluidPort;
            port dischargePort : BarrierFluidPort;
            attribute ratedFlowRate : FlowRateValue;
            attribute dischargePressure : PressureValue;
            attribute powerConsumption :> ISQ::power;
        }

        part def FilterAssembly {
            port inletPort : ~BarrierFluidPort;
            port outletPort : BarrierFluidPort;
            attribute micronRating : Real;
            attribute differentialPressure : PressureValue;
            attribute maxDifferentialPressure : PressureValue;
            assert constraint {
                differentialPressure <= maxDifferentialPressure
            }
        }

        part def HeatExchanger {
            port fluidInletPort : ~BarrierFluidPort;
            port fluidOutletPort : BarrierFluidPort;
            attribute coolingCapacity :> ISQ::power;
            attribute inletTemperature : TemperatureValue;
            attribute outletTemperature : TemperatureValue;
        }

        part def MechanicalSealInterface {
            port barrierFluidInPort : ~BarrierFluidPort;
            port barrierFluidOutPort : BarrierFluidPort;
            attribute sealPressure : PressureValue;
            attribute processPressure : PressureValue;
            attribute sealFaceTemperature : TemperatureValue;
            assert constraint {
                sealPressure > processPressure
            }
        }

        part def InstrumentationPanel {
            port monitoringPort : ~SignalPort;
            attribute pressureSetpoint : PressureValue;
            attribute temperatureSetpoint : TemperatureValue;
            attribute lowLevelSetpoint : VolumeValue;
            attribute criticalLowLevelSetpoint : VolumeValue;
            attribute highTemperatureSetpoint : TemperatureValue;
            attribute criticalHighTemperatureSetpoint : TemperatureValue;
            attribute lowPressureSetpoint : PressureValue;
            attribute criticalLowPressureSetpoint : PressureValue;
            attribute currentPressure : PressureValue;
            attribute currentTemperature : TemperatureValue;
            attribute currentLevel : VolumeValue;
            attribute resetRequested : Boolean;
            exhibit state monitoringStates : MonitoringStates;
        }

        part def RotatingEquipment {
            attribute equipmentType : String;
            attribute processPressure : PressureValue;
        }

        requirement def PressureDifferentialRequirement {
            doc /* Barrier fluid pressure must exceed process pressure to prevent leakage. */
            subject seal : MechanicalSealInterface;
            assert constraint { seal.sealPressure > seal.processPressure }
        }

        requirement def TemperatureControlRequirement {
            doc /* Heat exchanger must maintain barrier fluid below maximum temperature. */
            subject cooler : HeatExchanger;
            attribute maxOutletTemperature : TemperatureValue;
            assert constraint { cooler.outletTemperature <= maxOutletTemperature }
        }

        requirement def FiltrationRequirement {
            doc /* Filter must remove particulates to protect precision seal faces. */
            subject filt : FilterAssembly;
            attribute maxMicronRating : Real;
            assert constraint { filt.micronRating <= maxMicronRating }
        }

        requirement def ReservoirCapacityRequirement {
            doc /* Reservoir must have sufficient barrier fluid capacity for operation. */
            subject tank : PressurizedReservoir;
            attribute minCapacity : VolumeValue;
            assert constraint { tank.capacity >= minCapacity }
        }

        requirement def EmergencyResponseRequirement {
            doc /* System must provide emergency shutdown for critical parameter deviations. */
            subject panel : InstrumentationPanel;
            assert constraint { panel.criticalLowPressureSetpoint < panel.lowPressureSetpoint }
        }
    }

    package Usages {
        part sealSupportSystem {
            part reservoir : PressurizedReservoir;
            part pump : CirculationPump {
                perform action circulateFluid : CirculateBarrierFluid {
                    in fluidIn = suctionPort.fluidOut;
                    out fluidOut = dischargePort.fluidOut;
                }
            }
            part filter : FilterAssembly;
            part heatExchanger : HeatExchanger;
            part sealInterface : MechanicalSealInterface;
            part instrumentation : InstrumentationPanel;
            part rotatingEquipment : RotatingEquipment;

            flow of barrierFluid : BarrierFluid
                from reservoir.fluidSupplyPort.fluidOut to pump.suctionPort.fluidOut;
            flow of barrierFluid : BarrierFluid
                from pump.dischargePort.fluidOut to filter.inletPort.fluidOut;
            flow of barrierFluid : BarrierFluid
                from filter.outletPort.fluidOut to heatExchanger.fluidInletPort.fluidOut;
            flow of barrierFluid : BarrierFluid
                from heatExchanger.fluidOutletPort.fluidOut to sealInterface.barrierFluidInPort.fluidOut;
            flow of barrierFluid : BarrierFluid
                from sealInterface.barrierFluidOutPort.fluidOut to reservoir.fluidReturnPort.fluidOut;

            interface : SignalInterface connect
                reservoirEnd ::> reservoir.instrumentationPort to
                panelEnd ::> instrumentation.monitoringPort;

            requirement pressureDiffReq : PressureDifferentialRequirement {
                subject seal = sealInterface;
            }
            requirement tempCtrlReq : TemperatureControlRequirement {
                subject cooler = heatExchanger;
            }
            requirement filtReq : FiltrationRequirement {
                subject filt = filter;
            }
            requirement reservoirReq : ReservoirCapacityRequirement {
                subject tank = reservoir;
            }
            requirement emergencyReq : EmergencyResponseRequirement {
                subject panel = instrumentation;
            }
        }
    }
}
