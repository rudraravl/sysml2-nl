package 'Industrial Fluid Transfer System' {
    private import ISQ::*;
    private import ScalarValues::*;

    package 'ValueTypes' {
        private import ISQ::*;
        item def Fluid {
            attribute density :> ISQ::massDensity;
            attribute dynamicViscosity :> ISQ::dynamicViscosity;
        }
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def ResetCommand;
        attribute def SystemHealthy;
        attribute def CriticalFault;
    }

    package 'PortDefinitions' {
        private import ISQ::*;
        private import ScalarValues::*;
        private import 'ValueTypes'::*;
        port def FluidPort {
            out item fluid : Fluid;
        }
        port def ElectricalPowerPort;
        port def MechanicalPowerPort {
            out attribute torque :> ISQ::torque;
            out attribute speed :> ISQ::angularVelocity;
        }
        port def ControlCommandPort {
            in attribute command;
        }
        port def SensorDataPort {
            out attribute measurement;
        }
    }

    package 'ActionDefinitions' {
        action def StartSystem;
        action def StopSystem;
        action def MonitorPressure;
        action def MonitorFlow;
        action def EmergencyStop;
        action def OpenReliefValve;
        action def CloseReliefValve;
    }

    package 'Calculations' {
        private import ISQ::*;
        calc def PumpFlowRate {
            in displacement :> ISQ::volume;
            in rotorSpeed :> ISQ::angularVelocity;
            return flowRate = displacement * rotorSpeed;
        }
        calc def MotorPower {
            in torque :> ISQ::torque;
            in angularSpeed :> ISQ::angularVelocity;
            return power = torque * angularSpeed;
        }
    }

    package 'PartDefinitions' {
        private import ISQ::*;
        private import ScalarValues::*;
        private import 'ValueTypes'::*;
        private import 'PortDefinitions'::*;
        private import 'ActionDefinitions'::*;
        private import 'Calculations'::*;

        part def SupplyTank {
            attribute capacity :> ISQ::volume = 10 [m^3];
            attribute fluidLevel :> ISQ::volume = 8 [m^3];
            port outlet : FluidPort;
            port returnInlet : FluidPort;
        }

        part def ReceivingTank {
            attribute capacity :> ISQ::volume = 5 [m^3];
            attribute pressure :> ISQ::pressure;
            port inlet : FluidPort;
        }

        part def IsolationValve {
            attribute open : Boolean = false;
            port inlet : FluidPort;
            port outlet : FluidPort;
            port command : ControlCommandPort;
        }

        part def WendelkolbenPump {
            attribute displacement :> ISQ::volume = 0.0005 [m^3];
            attribute rotorSpeed :> ISQ::angularVelocity;
            attribute torque :> ISQ::torque;
            attribute flowRate :> ISQ::volumeFlowRate;
            port inlet : FluidPort;
            port outlet : FluidPort;
            port driveShaft : MechanicalPowerPort;
            
            part rotor {
                comment /* Helical metal rotor */
            }
            part stator {
                comment /* Flexible elastomeric stator */
            }
            
            calc 'PumpFlowRateCalc' : PumpFlowRate {
                in displacement = displacement;
                in rotorSpeed = rotorSpeed;
            }
            bind flowRate = 'PumpFlowRateCalc'.flowRate;
        }

        part def ElectricMotor {
            attribute ratedPower :> ISQ::power = 15000 [W];
            attribute torque :> ISQ::torque;
            attribute angularSpeed :> ISQ::angularVelocity;
            attribute actualPower :> ISQ::power;
            attribute enabled : Boolean = false;
            port electricalPower : ElectricalPowerPort;
            port driveShaft : ~MechanicalPowerPort;
            port command : ControlCommandPort;
            
            calc 'MotorPowerCalc' : MotorPower {
                in torque = torque;
                in angularSpeed = angularSpeed;
            }
            bind actualPower = 'MotorPowerCalc'.power;
        }

        part def PressureSensor {
            attribute measuredPressure :> ISQ::pressure;
            port processInlet : FluidPort;
            port processOutlet : FluidPort;
            port data : SensorDataPort;
        }

        part def FlowMeter {
            attribute measuredFlowRate :> ISQ::volumeFlowRate;
            port inlet : FluidPort;
            port outlet : FluidPort;
            port data : SensorDataPort;
        }

        part def PressureReliefValve {
            attribute setPressure :> ISQ::pressure = 1000000 [Pa];
            attribute open : Boolean = false;
            port inlet : FluidPort;
            port outlet : FluidPort;
        }

        part def SystemController {
            port pumpCmd : ControlCommandPort;
            port motorCmd : ControlCommandPort;
            port inletValveCmd : ControlCommandPort;
            port outletValveCmd : ControlCommandPort;
            port sensorDataInletPressure : SensorDataPort;
            port sensorDataOutletPressure : SensorDataPort;
            port sensorDataFlow : SensorDataPort;
            
            perform action startSystem : StartSystem;
            perform action stopSystem : StopSystem;
            perform action monitorPressure : MonitorPressure;
            perform action monitorFlow : MonitorFlow;
            perform action emergencyStop : EmergencyStop;
            perform action openReliefValve : OpenReliefValve;
            perform action closeReliefValve : CloseReliefValve;
        }

        part def FluidTransferSystem {
            attribute maxPressure :> ISQ::pressure = 1000000 [Pa];
            attribute minFlowRate :> ISQ::volumeFlowRate = 1.66667e-5 [m^3/s];
            
            part supplyTank : SupplyTank;
            part inletValve : IsolationValve;
            part pump : WendelkolbenPump;
            part motor : ElectricMotor;
            part inletPressureSensor : PressureSensor;
            part outletPressureSensor : PressureSensor;
            part flowMeter : FlowMeter;
            part reliefValve : PressureReliefValve;
            part outletValve : IsolationValve;
            part receivingTank : ReceivingTank;
            part controller : SystemController;

            connect supplyTank.outlet to inletValve.inlet;
            connect inletValve.outlet to inletPressureSensor.processInlet;
            connect inletPressureSensor.processOutlet to pump.inlet;
            connect pump.outlet to outletPressureSensor.processInlet;
            connect outletPressureSensor.processOutlet to reliefValve.inlet;
            connect outletPressureSensor.processOutlet to flowMeter.inlet;
            connect flowMeter.outlet to outletValve.inlet;
            connect outletValve.outlet to receivingTank.inlet;
            connect reliefValve.outlet to supplyTank.returnInlet;
            connect motor.driveShaft to pump.driveShaft;
            
            connect controller.motorCmd to motor.command;
            connect controller.inletValveCmd to inletValve.command;
            connect controller.outletValveCmd to outletValve.command;
            connect inletPressureSensor.data to controller.sensorDataInletPressure;
            connect outletPressureSensor.data to controller.sensorDataOutletPressure;
            connect flowMeter.data to controller.sensorDataFlow;

            perform action startSystem : StartSystem;
            perform action stopSystem : StopSystem;
            perform action monitorPressure : MonitorPressure;
            perform action monitorFlow : MonitorFlow;
            perform action emergencyStop : EmergencyStop;
            perform action openReliefValve : OpenReliefValve;
            perform action closeReliefValve : CloseReliefValve;

            exhibit state systemStates {
                entry; then stopped;

                state stopped {
                    entry closeReliefValve;
                    do stopSystem;
                }

                state starting {
                    entry startSystem;
                }

                state normal {
                    entry monitorPressure;
                    do monitorFlow;
                }

                state highPressure {
                    entry openReliefValve;
                }

                state lowFlow {
                }

                state fault {
                    entry emergencyStop;
                }

                transition stopped_to_starting
                    first stopped
                    accept StartCommand
                    then starting;

                transition starting_to_normal
                    first starting
                    accept SystemHealthy
                    then normal;

                transition normal_to_highPressure
                    first normal
                    accept when outletPressureSensor.measuredPressure > reliefValve.setPressure
                    then highPressure;

                transition highPressure_to_normal
                    first highPressure
                    accept when outletPressureSensor.measuredPressure <= reliefValve.setPressure * 0.9
                    then normal;

                transition normal_to_lowFlow
                    first normal
                    accept when flowMeter.measuredFlowRate < minFlowRate
                    then lowFlow;

                transition lowFlow_to_normal
                    first lowFlow
                    accept when flowMeter.measuredFlowRate >= minFlowRate
                    then normal;

                transition normal_to_fault
                    first normal
                    accept CriticalFault
                    then fault;

                transition highPressure_to_fault
                    first highPressure
                    accept CriticalFault
                    then fault;

                transition lowFlow_to_fault
                    first lowFlow
                    accept CriticalFault
                    then fault;

                transition fault_to_stopped
                    first fault
                    accept ResetCommand
                    then stopped;

                transition stopped_to_fault
                    first stopped
                    accept CriticalFault
                    then fault;
            }
        }
    }

    package 'RequirementDefinitions' {
        private import ISQ::*;
        requirement def MaxOutletPressure {
            doc /* The pump outlet pressure shall not exceed 10 bar. */
            attribute limit :> ISQ::pressure = 1000000 [Pa];
        }

        requirement def MinFlowRate {
            doc /* The discharge flow rate shall be at least 1 L/min during normal operation. */
            attribute minFlow :> ISQ::volumeFlowRate = 1.66667e-5 [m^3/s];
        }

        requirement def MotorPowerRating {
            doc /* The electric motor shall provide at least 15 kW continuous power. */
            attribute minPower :> ISQ::power = 15000 [W];
        }

        requirement def ReliefValveSetPoint {
            doc /* The pressure relief valve shall open at 10 bar to protect the system. */
            attribute setPoint :> ISQ::pressure = 1000000 [Pa];
        }

        requirement def OverpressureProtection {
            doc /* The system shall prevent pressure from exceeding 10 bar by diverting flow via the relief valve. */
        }

        requirement def ContinuousOperation {
            doc /* The system shall be capable of continuous operation under normal conditions. */
        }
    }
}
