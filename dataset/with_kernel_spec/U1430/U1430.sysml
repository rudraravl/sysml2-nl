package IndustrialCentrifugalPumpSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        item def ProcessFluid {
            attribute density :> ISQ::massDensity;
            attribute temperature :> ISQ::temperature;
            attribute viscosity :> ISQ::dynamicViscosity;
        }

        attribute def ElectricalPower {
            attribute voltage :> ISQ::electricPotential;
            attribute current :> ISQ::electricCurrent;
            attribute frequency :> ISQ::frequency;
        }

        attribute def MechanicalPower {
            attribute torque :> ISQ::torque;
            attribute rotationalSpeed :> ISQ::angularVelocity;
        }

        item def StartCommand;
        item def StopCommand;
        item def SpeedCommand {
            attribute targetSpeed :> ISQ::angularVelocity;
        }
        item def PrimeCompleteSignal;
        item def TargetSpeedReachedSignal;
        item def MotorStoppedSignal;
        item def CavitationDetectedSignal;
        item def CavitationResolvedSignal;
        item def RunoutDetectedSignal;
        item def RunoutResolvedSignal;

        port def ElectricalPort {
            in attribute power : ElectricalPower;
        }

        port def MechanicalPort {
            in attribute mechPower : MechanicalPower;
        }

        port def FluidPort {
            in item fluid : ProcessFluid;
            attribute pressure :> ISQ::pressure;
            attribute flowRate :> ISQ::volumeFlowRate;
        }

        port def ControlPort {
            in item startCmd : StartCommand;
            in item stopCmd : StopCommand;
            in item speedCmd : SpeedCommand;
        }

        port def SensorDataPort {
            attribute suctionPressureReading :> ISQ::pressure;
            attribute dischargePressureReading :> ISQ::pressure;
            attribute dischargeFlowReading :> ISQ::volumeFlowRate;
        }

        part def VariableFrequencyDrive {
            attribute ratedPower :> ISQ::power;
            attribute outputFrequency :> ISQ::frequency;
            attribute outputVoltage :> ISQ::electricPotential;
            port powerIn : ElectricalPort;
            port powerOut : ElectricalPort;
            port controlIn : ControlPort;
            perform action regulateSpeed;
        }

        part def ElectricMotor {
            attribute ratedPower :> ISQ::power;
            attribute ratedSpeed :> ISQ::angularVelocity;
            attribute efficiency : Real;
            port powerIn : ElectricalPort;
            port mechOut : MechanicalPort;
            perform action convertEnergy;
        }

        part def Bearing {
            attribute type : String;
            attribute loadCapacity :> ISQ::force;
        }

        part def Shaft {
            attribute material : String = "Steel";
            attribute diameter :> ISQ::length;
            attribute length :> ISQ::length;
            attribute maxTorque :> ISQ::torque;
            port mechIn : MechanicalPort;
            port mechOut : MechanicalPort;
            part radialBearing : Bearing;
            part thrustBearing : Bearing;
        }

        part def Impeller {
            attribute diameter :> ISQ::length;
            attribute bladeCount : Integer;
            port mechIn : MechanicalPort;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            perform action impartEnergy;
        }

        part def Volute {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            perform action convertKineticToPressure;
        }

        part def MechanicalSeal {
            attribute leakageRate :> ISQ::volumeFlowRate;
            attribute material : String;
        }

        part def PumpCasing {
            attribute material : String = "Ductile Iron";
            attribute designPressure :> ISQ::pressure;
            attribute designTemperature :> ISQ::temperature;
            port suctionNozzle : FluidPort;
            port dischargeNozzle : FluidPort;
            part volute : Volute;
            part mechanicalSeal : MechanicalSeal;
        }

        part def PressureTransmitter {
            attribute measuredPressure :> ISQ::pressure;
            attribute rangeMin :> ISQ::pressure;
            attribute rangeMax :> ISQ::pressure;
            port processPort : FluidPort;
            port dataOut : SensorDataPort;
            perform action measurePressure;
        }

        part def FlowTransmitter {
            attribute measuredFlowRate :> ISQ::volumeFlowRate;
            attribute rangeMin :> ISQ::volumeFlowRate;
            attribute rangeMax :> ISQ::volumeFlowRate;
            port processPort : FluidPort;
            port dataOut : SensorDataPort;
            perform action measureFlow;
        }

        action def PrimePump;
        action def OpenSuctionValve;
        action def OpenDischargeValve;
        action def CloseSuctionValve;
        action def CloseDischargeValve;
        action def RampMotorSpeed;
        action def RampDownMotor;
        action def MonitorCavitation;
        action def MonitorRunout;
        action def TriggerCavitationAlarm;
        action def TriggerRunoutAlarm;
        action def ReduceSpeed;
        action def ThrottleDischarge;

        action def MonitorOperation {
            action monitorCavitation : MonitorCavitation;
            action monitorRunout : MonitorRunout;
        }

        part def CentrifugalPumpSystem {
            attribute systemFlowRate :> ISQ::volumeFlowRate;
            attribute suctionPressure :> ISQ::pressure;
            attribute dischargePressure :> ISQ::pressure;
            attribute minSuctionPressure :> ISQ::pressure;
            attribute maxFlowRate :> ISQ::volumeFlowRate;
            attribute minDischargePressure :> ISQ::pressure;

            port powerIn : ElectricalPort;
            port suctionPort : FluidPort;
            port dischargePort : FluidPort;
            port controlPort : ControlPort;
            port sensorDataOut : SensorDataPort;

            part vfd : VariableFrequencyDrive;
            part motor : ElectricMotor;
            part shaft : Shaft;
            part impeller : Impeller;
            part casing : PumpCasing;
            part suctionPressureTx : PressureTransmitter;
            part dischargePressureTx : PressureTransmitter;
            part dischargeFlowTx : FlowTransmitter;

            perform action primePump : PrimePump;
            perform action openSuctionValve : OpenSuctionValve;
            perform action openDischargeValve : OpenDischargeValve;
            perform action closeSuctionValve : CloseSuctionValve;
            perform action closeDischargeValve : CloseDischargeValve;
            perform action rampMotorSpeed : RampMotorSpeed;
            perform action rampDownMotor : RampDownMotor;
            perform action monitorOperation : MonitorOperation;
            perform action triggerCavitationAlarm : TriggerCavitationAlarm;
            perform action triggerRunoutAlarm : TriggerRunoutAlarm;
            perform action reduceSpeed : ReduceSpeed;
            perform action throttleDischarge : ThrottleDischarge;

            connect powerIn to vfd.powerIn;
            connect vfd.powerOut to motor.powerIn;
            connect motor.mechOut to shaft.mechIn;
            connect shaft.mechOut to impeller.mechIn;
            connect suctionPort to casing.suctionNozzle;
            connect casing.suctionNozzle to impeller.fluidIn;
            connect impeller.fluidOut to casing.volute.fluidIn;
            connect casing.volute.fluidOut to casing.dischargeNozzle;
            connect casing.dischargeNozzle to dischargePort;
            connect suctionPort to suctionPressureTx.processPort;
            connect dischargePort to dischargePressureTx.processPort;
            connect dischargePort to dischargeFlowTx.processPort;
            connect suctionPressureTx.dataOut to sensorDataOut;
            connect dischargePressureTx.dataOut to sensorDataOut;
            connect dischargeFlowTx.dataOut to sensorDataOut;
            connect controlPort to vfd.controlIn;

            exhibit state pumpStates parallel {
                state operationalStates {
                    entry; then off;
                    state off;
                    transition off_to_priming
                        first off
                        accept StartCommand via controlPort
                        then priming;
                    state priming {
                        entry action primePump;
                        do openSuctionValve;
                    }
                    transition priming_to_starting
                        first priming
                        accept PrimeCompleteSignal
                        then starting;
                    state starting {
                        entry action rampMotorSpeed;
                        do openDischargeValve;
                    }
                    transition starting_to_running
                        first starting
                        accept TargetSpeedReachedSignal
                        then running;
                    state running {
                        do monitorOperation;
                    }
                    transition running_to_stopping
                        first running
                        accept StopCommand via controlPort
                        then stopping;
                    state stopping {
                        entry action rampDownMotor;
                        do closeDischargeValve;
                        exit action closeSuctionValve;
                    }
                    transition stopping_to_off
                        first stopping
                        accept MotorStoppedSignal
                        then off;
                }
                state healthStates {
                    entry; then normal;
                    state normal;
                    transition normal_to_cavitation
                        first normal
                        accept CavitationDetectedSignal
                        then cavitation;
                    state cavitation {
                        entry action triggerCavitationAlarm;
                        do reduceSpeed;
                    }
                    transition cavitation_to_normal
                        first cavitation
                        accept CavitationResolvedSignal
                        then normal;
                    transition normal_to_runout
                        first normal
                        accept RunoutDetectedSignal
                        then runout;
                    state runout {
                        entry action triggerRunoutAlarm;
                        do throttleDischarge;
                    }
                    transition runout_to_normal
                        first runout
                        accept RunoutResolvedSignal
                        then normal;
                }
            }
        }

        requirement def PumpPerformanceRequirement {
            subject pump : CentrifugalPumpSystem;
            attribute requiredFlowRate :> ISQ::volumeFlowRate;
            attribute requiredDischargePressure :> ISQ::pressure;
            require constraint {
                pump.systemFlowRate >= requiredFlowRate and
                pump.dischargePressure >= requiredDischargePressure
            }
        }

        requirement def CavitationProtectionRequirement {
            subject pump : CentrifugalPumpSystem;
            doc /* The system shall detect and mitigate cavitation conditions. */
            require constraint {
                pump.suctionPressure >= pump.minSuctionPressure
            }
        }

        requirement def RunoutProtectionRequirement {
            subject pump : CentrifugalPumpSystem;
            doc /* The system shall detect and mitigate runout conditions. */
            require constraint {
                pump.systemFlowRate <= pump.maxFlowRate
            }
        }

        requirement def StructuralIntegrityRequirement {
            subject pump : CentrifugalPumpSystem;
            doc /* The pump casing shall withstand design pressure and temperature. */
            require constraint {
                pump.dischargePressure <= pump.casing.designPressure
            }
        }

        requirement def StartupSequenceRequirement {
            subject pump : CentrifugalPumpSystem;
            doc /* The system shall follow a defined startup sequence including priming and gradual valve opening. */
        }
    }

    package Instances {
        part systemUnderTest : Definitions::CentrifugalPumpSystem;

        requirement performanceSpec : Definitions::PumpPerformanceRequirement {
            subject pump = systemUnderTest;
            attribute requiredFlowRate = 100 [m^3/min];
            attribute requiredDischargePressure = 500000 [Pa];
        }

        requirement cavitationSpec : Definitions::CavitationProtectionRequirement {
            subject pump = systemUnderTest;
        }

        requirement runoutSpec : Definitions::RunoutProtectionRequirement {
            subject pump = systemUnderTest;
        }

        requirement structuralSpec : Definitions::StructuralIntegrityRequirement {
            subject pump = systemUnderTest;
        }

        requirement startupSpec : Definitions::StartupSequenceRequirement {
            subject pump = systemUnderTest;
        }
    }
}
