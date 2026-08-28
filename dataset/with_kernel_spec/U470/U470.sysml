package AxialFlowPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        // ---- Value Types ----
        attribute def RotationalSpeed :> ISQ::angularVelocity;
        attribute def TorqueValue :> ISQ::torque;
        attribute def FlowRateValue :> ISQ::volumeFlowRate;
        attribute def PressureValue :> ISQ::pressure;
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def LengthValue :> ISQ::length;
        attribute def PowerValue :> ISQ::power;
        attribute def MassValue :> ISQ::mass;
        attribute def TimeValue :> ISQ::time;
        attribute def DensityValue :> ISQ::massDensity;
        attribute def ViscosityValue :> ISQ::dynamicViscosity;
        attribute def VoltageValue :> ISQ::electricPotential;
        attribute def CurrentValue :> ISQ::electricCurrent;

        // ---- Item Definitions ----
        item def Fluid {
            attribute density : DensityValue;
            attribute viscosity : ViscosityValue;
        }

        // ---- Signal Definitions ----
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def FaultSignal;
        attribute def ResetCommand;
        attribute def AtSpeedSignal;
        attribute def StoppedSignal;

        // ---- Port Definitions ----
        port def FluidPort {
            out fluidFlow : FlowRateValue;
            out pressure : PressureValue;
            out temperature : TemperatureValue;
        }
        port def FluidInPort :> FluidPort {
            in fluidFlow : FlowRateValue;
            in pressure : PressureValue;
            in temperature : TemperatureValue;
        }
        port def FluidOutPort :> FluidPort;
        port def MechanicalPowerPort {
            out torque : TorqueValue;
            out speed : RotationalSpeed;
        }
        port def MechanicalLoadPort :> MechanicalPowerPort {
            in torque : TorqueValue;
            in speed : RotationalSpeed;
        }
        port def ElectricalPowerPort {
            in voltage : VoltageValue;
            in current : CurrentValue;
        }
        port def ControlPort {
            in command;
            out status;
        }
        port def InstrumentPort {
            out measurement;
        }

        // ---- Action Definitions ----
        action def DrawFluid {
            in fluidIn : FlowRateValue;
            out fluidOut : FlowRateValue;
        }
        action def PressurizeFluid {
            in fluidIn : FlowRateValue;
            in speed : RotationalSpeed;
            out fluidOut : FlowRateValue;
            out pressureOut : PressureValue;
        }
        action def DeliverFluid {
            in fluidIn : FlowRateValue;
            out fluidOut : FlowRateValue;
        }
        action def RampUp {
            out targetSpeed : RotationalSpeed;
        }
        action def RampDown {
            out targetSpeed : RotationalSpeed;
        }
        action def MonitorConditions {
            in suctionFlow : FlowRateValue;
            in suctionPressure : PressureValue;
            in suctionTemperature : TemperatureValue;
            in dischargePressure : PressureValue;
            in dischargeTemperature : TemperatureValue;
            out faultDetected : Boolean;
        }

        // ---- State Definitions ----
        state def PumpStates {
            entry; then off;
            state off;
            transition off_to_starting
                first off
                accept StartCommand
                then starting;
            state starting {
                perform action rampUp : RampUp;
            }
            transition starting_to_running
                first starting
                accept AtSpeedSignal
                then running;
            state running;
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            transition running_to_fault
                first running
                accept FaultSignal
                then fault;
            state stopping {
                perform action rampDown : RampDown;
            }
            transition stopping_to_off
                first stopping
                accept StoppedSignal
                then off;
            state fault;
            transition fault_to_off
                first fault
                accept ResetCommand
                then off;
        }

        // ---- Part Definitions ----
        part def Impeller {
            attribute bladeCount : Integer;
            attribute bladeMaterial = "Stainless Steel";
            attribute diameter : LengthValue;
            port mechanicalPort : MechanicalLoadPort;
            assert constraint { bladeCount >= 4 & bladeCount <= 12 }
        }

        part def Shaft {
            attribute material = "Stainless Steel";
            attribute diameter : LengthValue;
            port driveEnd : MechanicalLoadPort;
            port impellerEnd : MechanicalPowerPort;
        }

        part def Bearing {
            attribute material = "Bronze";
            port supportPort : MechanicalLoadPort;
        }

        part def MechanicalSeal {
            attribute sealType = "Mechanical";
            port shaftPort : MechanicalLoadPort;
            port housingPort : MechanicalLoadPort;
        }

        part def Casing {
            attribute material = "Cast Iron";
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
            port impellerPort : FluidPort;
        }

        part def AxialFlowPump {
            attribute ratedSpeed : RotationalSpeed = 1450 [rev/min];
            attribute maxFlowRate : FlowRateValue;
            attribute casingMaterial = "Cast Iron";
            attribute shaftMaterial = "Stainless Steel";
            port fluidInlet : FluidInPort;
            port fluidOutlet : FluidOutPort;
            port mechanicalInput : MechanicalLoadPort;
            part impeller : Impeller {
                attribute redefines bladeCount = 7;
                attribute redefines diameter = 0.8 [m];
            }
            part shaft : Shaft {
                attribute redefines material = shaftMaterial;
            }
            part inletBearing : Bearing;
            part outletBearing : Bearing;
            part mechanicalSeal : MechanicalSeal;
            part casing : Casing {
                attribute redefines material = casingMaterial;
            }
            connect impeller.mechanicalPort to shaft.impellerEnd;
            connect shaft.driveEnd to mechanicalInput;
            connect shaft to inletBearing.supportPort;
            connect shaft to outletBearing.supportPort;
            connect mechanicalSeal.shaftPort to shaft;
            connect mechanicalSeal.housingPort to casing;
            connect impeller to casing.impellerPort;
            connect casing.inletPort to fluidInlet;
            connect casing.outletPort to fluidOutlet;
            perform action pressurize : PressurizeFluid;
            exhibit state pumpStates : PumpStates;
        }

        part def ElectricMotor {
            attribute ratedPower : PowerValue;
            attribute ratedSpeed : RotationalSpeed = 1450 [rev/min];
            port electricalInput : ElectricalPowerPort;
            port mechanicalOutput : MechanicalPowerPort;
            perform action convertPower;
        }

        part def SuctionPiping {
            attribute length : LengthValue;
            attribute diameter : LengthValue;
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }

        part def DischargePiping {
            attribute length : LengthValue;
            attribute diameter : LengthValue;
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }

        part def IsolationValve {
            attribute valveType = "Gate";
            attribute isOpen : Boolean;
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }

        part def CheckValve {
            attribute valveType = "Swing Check";
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }

        part def FlowMeter {
            attribute measuredFlow : FlowRateValue;
            port fluidPort : FluidInPort;
            port instrumentPort : InstrumentPort;
        }

        part def PressureTransmitter {
            attribute measuredPressure : PressureValue;
            port fluidPort : FluidInPort;
            port instrumentPort : InstrumentPort;
        }

        part def TemperatureTransmitter {
            attribute measuredTemperature : TemperatureValue;
            port fluidPort : FluidInPort;
            port instrumentPort : InstrumentPort;
        }

        part def PumpController {
            port controlPort : ControlPort;
            port suctionFlowPort : InstrumentPort;
            port suctionPressurePort : InstrumentPort;
            port suctionTemperaturePort : InstrumentPort;
            port dischargePressurePort : InstrumentPort;
            port dischargeTemperaturePort : InstrumentPort;
            exhibit state controllerStates : PumpStates;
            perform action monitorConditions : MonitorConditions;
        }

        part def PumpingSubsystem {
            attribute totalMass : MassValue;
            attribute designFlowRate : FlowRateValue;
            attribute maxDischargePressure : PressureValue;
            port suctionInlet : FluidInPort;
            port dischargeOutlet : FluidOutPort;
            port electricalPowerIn : ElectricalPowerPort;
            part pump : AxialFlowPump;
            part motor : ElectricMotor;
            part suctionPiping : SuctionPiping;
            part dischargePiping : DischargePiping;
            part suctionIsolationValve : IsolationValve;
            part dischargeIsolationValve : IsolationValve;
            part checkValve : CheckValve;
            part suctionFlowMeter : FlowMeter;
            part suctionPressureTransmitter : PressureTransmitter;
            part suctionTemperatureTransmitter : TemperatureTransmitter;
            part dischargePressureTransmitter : PressureTransmitter;
            part dischargeTemperatureTransmitter : TemperatureTransmitter;
            part controller : PumpController;
            connect motor.mechanicalOutput to pump.mechanicalInput;
            connect suctionInlet to suctionPiping.inlet;
            connect suctionPiping.outlet to suctionIsolationValve.inlet;
            connect suctionIsolationValve.outlet to suctionFlowMeter.fluidPort;
            connect suctionFlowMeter.fluidPort to suctionPressureTransmitter.fluidPort;
            connect suctionPressureTransmitter.fluidPort to suctionTemperatureTransmitter.fluidPort;
            connect suctionTemperatureTransmitter.fluidPort to pump.fluidInlet;
            connect pump.fluidOutlet to checkValve.inlet;
            connect checkValve.outlet to dischargePressureTransmitter.fluidPort;
            connect dischargePressureTransmitter.fluidPort to dischargeTemperatureTransmitter.fluidPort;
            connect dischargeTemperatureTransmitter.fluidPort to dischargeIsolationValve.inlet;
            connect dischargeIsolationValve.outlet to dischargePiping.inlet;
            connect dischargePiping.outlet to dischargeOutlet;
            connect electricalPowerIn to motor.electricalInput;
            connect suctionFlowMeter.instrumentPort to controller.suctionFlowPort;
            connect suctionPressureTransmitter.instrumentPort to controller.suctionPressurePort;
            connect suctionTemperatureTransmitter.instrumentPort to controller.suctionTemperaturePort;
            connect dischargePressureTransmitter.instrumentPort to controller.dischargePressurePort;
            connect dischargeTemperatureTransmitter.instrumentPort to controller.dischargeTemperaturePort;
            exhibit state systemStates : PumpStates;
            perform action pumpFluid : PressurizeFluid;
            perform action monitorConditions : MonitorConditions;
        }

        // ---- Requirement Definitions ----
        requirement def FlowRateRequirement {
            doc /* The system shall deliver a minimum flow rate for high-volume applications. */
            attribute minFlowRate : FlowRateValue;
            attribute maxFlowRate : FlowRateValue;
            constraint {
                minFlowRate <= maxFlowRate
            }
        }

        requirement def PressureRequirement {
            doc /* The discharge pressure shall not exceed the maximum design pressure. */
            attribute maxDischargePressure : PressureValue;
        }

        requirement def SpeedRequirement {
            doc /* The pump shall operate at the specified rated speed. */
            attribute ratedSpeed : RotationalSpeed;
        }

        requirement def ReliabilityRequirement {
            doc /* The system shall be capable of continuous operation for a minimum duration. */
            attribute minMTBF : TimeValue;
        }

        requirement def BladeCountRequirement {
            doc /* The impeller shall have between 4 and 12 blades. */
            attribute minBladeCount : Integer = 4;
            attribute maxBladeCount : Integer = 12;
            constraint {
                minBladeCount >= 4 & maxBladeCount <= 12
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part pumpingSubsystem : PumpingSubsystem {
            attribute redefines designFlowRate = 5000 [m^3/h];
            attribute redefines maxDischargePressure = 200000 [Pa];

            part redefines suctionPiping {
                attribute redefines length = 10 [m];
                attribute redefines diameter = 0.5 [m];
            }
            part redefines dischargePiping {
                attribute redefines length = 20 [m];
                attribute redefines diameter = 0.5 [m];
            }
            part redefines pump {
                attribute redefines ratedSpeed = 1450 [rev/min];
                part redefines impeller {
                    attribute redefines bladeCount = 7;
                    attribute redefines diameter = 0.8 [m];
                }
            }
            part redefines motor {
                attribute redefines ratedPower = 500 [kW];
                attribute redefines ratedSpeed = 1450 [rev/min];
            }

            satisfy flowReq by pump;
            satisfy pressureReq by pump;
            satisfy speedReq by motor;
            satisfy bladeCountReq by pump.impeller;
        }

        requirement flowReq : FlowRateRequirement {
            attribute minFlowRate = 5000 [m^3/h];
            attribute maxFlowRate = 8000 [m^3/h];
        }

        requirement pressureReq : PressureRequirement {
            attribute maxDischargePressure = 200000 [Pa];
        }

        requirement speedReq : SpeedRequirement {
            attribute ratedSpeed = 1450 [rev/min];
        }

        requirement reliabilityReq : ReliabilityRequirement {
            attribute minMTBF = 8000 [h];
        }

        requirement bladeCountReq : BladeCountRequirement {
            attribute minBladeCount = 4;
            attribute maxBladeCount = 12;
        }
    }
}
