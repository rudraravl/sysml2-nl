package 'Euler Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package PhysicalQuantities {
        attribute def AngularVelocity {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Velocity {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Radius {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def FlowRate {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Pressure {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Power {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Density {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Head {
            attribute num: Real;
            attribute unit: String;
        }
        
        attribute def Efficiency {
            attribute num: Real;
        }
        
        attribute def Torque {
            attribute num: Real;
            attribute unit: String;
        }
    }

    package FluidDynamics {
        private import PhysicalQuantities::*;
        
        item def Fluid {
            attribute density : Density;
            attribute viscosity : Real;
            attribute temperature : Real;
        }
        
        port def FluidPort {
            attribute pressure : Pressure;
            attribute flowRate : FlowRate;
            attribute velocity : Velocity;
            out item fluid : Fluid;
        }
        
        calc def EulerPumpEquation {
            in u2 : Velocity;
            in u1 : Velocity;
            in vt2 : Velocity;
            in vt1 : Velocity;
            in g : Real;
            return head : Real;
        }
        
        calc def EulerTurbineEquation {
            in u1 : Velocity;
            in u2 : Velocity;
            in vt1 : Velocity;
            in vt2 : Velocity;
            in g : Real;
            return head : Real;
        }
        
        calc def TangentialVelocity {
            in omega : AngularVelocity;
            in radius : Radius;
            return velocity : Velocity;
        }
        
        calc def HydraulicPower {
            in rho : Density;
            in Q : FlowRate;
            in H : Head;
            in g : Real;
            return power : Power;
        }
        
        calc def ShaftPower {
            in hydraulicPower : Power;
            in efficiency : Efficiency;
            return power : Power;
        }
    }

    package Components {
        private import PhysicalQuantities::*;
        private import FluidDynamics::*;
        
        part def Impeller {
            attribute inletRadius : Radius;
            attribute outletRadius : Radius;
            attribute rotationalSpeed : AngularVelocity;
            attribute bladeCount : Integer;
            attribute bladeAngle : Real;
            attribute inletTangentialVelocity : Velocity;
            attribute outletTangentialVelocity : Velocity;
        }
        
        part def Volute {
            attribute crossSectionalArea : Real;
            attribute diffuserAngle : Real;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }
        
        part def Runner {
            attribute inletRadius : Radius;
            attribute outletRadius : Radius;
            attribute rotationalSpeed : AngularVelocity;
            attribute bladeCount : Integer;
            attribute bladeAngle : Real;
            attribute inletTangentialVelocity : Velocity;
            attribute outletTangentialVelocity : Velocity;
        }
        
        part def DraftTube {
            attribute inletArea : Real;
            attribute outletArea : Real;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }
        
        part def Motor {
            attribute ratedPower : Power;
            attribute efficiency : Efficiency;
            attribute operatingSpeed : AngularVelocity;
            port powerOutput;
        }
        
        part def Generator {
            attribute ratedPower : Power;
            attribute efficiency : Efficiency;
            attribute operatingSpeed : AngularVelocity;
            port powerInput;
        }
        
        part def CentrifugalPump {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port drivePort;
            
            part impeller : Impeller;
            part volute : Volute;
            
            attribute headDeveloped : Head;
            attribute hydraulicEfficiency : Efficiency;
            attribute mechanicalEfficiency : Efficiency;
            attribute volumetricEfficiency : Efficiency;
            attribute overallEfficiency : Efficiency;
            attribute theoreticalHead : Real;
            attribute actualHead : Head;
            attribute hydraulicPowerOutput : Power;
            attribute shaftPowerInput : Power;
            
            connect volute.inletPort to outletPort;
        }
        
        part def HydraulicTurbine {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port outputPort;
            
            part runner : Runner;
            part draftTube : DraftTube;
            
            attribute headExtracted : Head;
            attribute hydraulicEfficiency : Efficiency;
            attribute mechanicalEfficiency : Efficiency;
            attribute overallEfficiency : Efficiency;
            attribute theoreticalHead : Real;
            attribute actualHead : Head;
            attribute hydraulicPowerInput : Power;
            attribute shaftPowerOutput : Power;
            
            connect draftTube.inletPort to runner;
            connect draftTube.outletPort to outletPort;
        }
        
        part def PressureSensor {
            port sensingPort : ~FluidPort;
            attribute measuredPressure : Pressure;
        }
        
        part def FlowMeter {
            port sensingPort : ~FluidPort;
            attribute measuredFlowRate : FlowRate;
        }
        
        part def Reservoir {
            port outletPort : FluidPort;
            attribute capacity : Real;
            attribute currentLevel : Real;
            item storedFluid : Fluid;
        }
        
        part def DischargeReservoir {
            port inletPort : ~FluidPort;
            attribute capacity : Real;
            attribute currentLevel : Real;
            item storedFluid : Fluid;
        }
    }

    package Behaviors {
        private import PhysicalQuantities::*;
        
        action def StartPump {
            in targetFlowRate : FlowRate;
            out pumpRunning : Boolean;
        }
        
        action def MonitorPumpOperation {
            in currentPressure : Pressure;
            in currentFlowRate : FlowRate;
            in targetFlowRate : FlowRate;
            out operatingStatus : Boolean;
        }
        
        action def AdjustPumpSpeed {
            in desiredFlowRate : FlowRate;
            in currentFlowRate : FlowRate;
            out newSpeed : AngularVelocity;
        }
        
        action def StopPump {
            out pumpStopped : Boolean;
        }
        
        action def StartTurbine {
            in availableHead : Real;
            out turbineRunning : Boolean;
        }
        
        action def MonitorTurbineOperation {
            in currentPower : Power;
            in targetPower : Power;
            out operatingStatus : Boolean;
        }
        
        action def AdjustTurbineSpeed {
            in desiredPower : Power;
            in currentPower : Power;
            out newSpeed : AngularVelocity;
        }
        
        action def StopTurbine {
            out turbineStopped : Boolean;
        }
        
        action def PumpingCycle {
            first start;
            then action startPump : StartPump;
            then merge monitorLoop;
            then action monitor : MonitorPumpOperation;
            then decide;
                if monitor.operatingStatus == false then adjust;
                if monitor.operatingStatus == true then continueMonitoring;
            action adjust : AdjustPumpSpeed;
            then monitorLoop;
            action continueMonitoring;
            then monitorLoop;
        }
        
        action def TurbineCycle {
            first start;
            then action startTurbine : StartTurbine;
            then merge monitorLoop;
            then action monitor : MonitorTurbineOperation;
            then decide;
                if monitor.operatingStatus == false then adjust;
                if monitor.operatingStatus == true then continueMonitoring;
            action adjust : AdjustTurbineSpeed;
            then monitorLoop;
            action continueMonitoring;
            then monitorLoop;
        }
        
        state def PumpOperatingStates {
            entry; then idle;
            
            state idle;
            transition idle_to_starting
                first idle
                accept StartCommand
                then starting;
            
            state starting;
            transition starting_to_running
                first starting
                if speedReached
                then running;
            
            state running {
                entry; then normalOperation;
                
                state normalOperation;
                transition to_highPressure
                    first normalOperation
                    if pressureHigh
                    then highPressure;
                
                state highPressure;
                transition to_normalOperation
                    first highPressure
                    if pressureNormal
                    then normalOperation;
            }
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            state stopping;
            transition stopping_to_idle
                first stopping
                if speedZero
                then idle;
            
            accept StartCommand;
            accept StopCommand;
            attribute speedReached : Boolean;
            attribute speedZero : Boolean;
            attribute pressureHigh : Boolean;
            attribute pressureNormal : Boolean;
        }
        
        state def TurbineOperatingStates {
            entry; then idle;
            
            state idle;
            transition idle_to_starting
                first idle
                accept StartCommand
                then starting;
            
            state starting;
            transition starting_to_running
                first starting
                if speedReached
                then running;
            
            state running {
                entry; then normalOperation;
                
                state normalOperation;
                transition to_overload
                    first normalOperation
                    if powerHigh
                    then overload;
                
                state overload;
                transition to_normalOperation
                    first overload
                    if powerNormal
                    then normalOperation;
            }
            
            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;
            
            state stopping;
            transition stopping_to_idle
                first stopping
                if speedZero
                then idle;
            
            accept StartCommand;
            accept StopCommand;
            attribute speedReached : Boolean;
            attribute speedZero : Boolean;
            attribute powerHigh : Boolean;
            attribute powerNormal : Boolean;
        }
    }

    package Requirements {
        private import PhysicalQuantities::*;
        private import Components::*;
        
        requirement def PumpPerformanceRequirement {
            doc /* The pump shall deliver the specified flow rate at the design head 
                   using Euler's pump equation. */
            
            subject pump : CentrifugalPump;
            
            require constraint flowRateConstraint {
                pump.outletPort.flowRate.num >= 0.1
            }
            
            require constraint headConstraint {
                pump.headDeveloped.num >= 50.0
            }
            
            require constraint efficiencyConstraint {
                pump.hydraulicEfficiency.num >= 0.75
            }
        }
        
        requirement def TurbinePerformanceRequirement {
            doc /* The turbine shall extract energy from fluid flow using Euler's 
                   turbine equation. */
            
            subject turbine : HydraulicTurbine;
            
            require constraint powerOutputConstraint {
                turbine.shaftPowerOutput.num >= 10000.0
            }
            
            require constraint efficiencyConstraint {
                turbine.overallEfficiency.num >= 0.85
            }
        }
        
        requirement def EulerEquationCompliance {
            doc /* The system shall calculate head and power using Euler's equations 
                   for turbomachinery. */
            
            require constraint pumpHeadCalculation {
                doc /* Pump head shall be calculated using Euler pump equation: 
                       H = (u2*vt2 - u1*vt1)/g */
            }
            
            require constraint turbineHeadCalculation {
                doc /* Turbine head shall be calculated using Euler turbine equation: 
                       H = (u1*vt1 - u2*vt2)/g */
            }
        }
        
        requirement def SystemSafetyRequirement {
            doc /* The pumping subsystem shall operate within safe limits. */
            
            require constraint maxPressureLimit {
                doc /* Maximum discharge pressure shall not exceed 15 bar. */
            }
            
            require constraint minFlowRate {
                doc /* Minimum flow rate shall be maintained to prevent cavitation. */
            }
            
            require constraint maxSpeed {
                doc /* Maximum rotational speed shall not exceed design limits. */
            }
        }
    }

    package System {
        private import PhysicalQuantities::*;
        private import FluidDynamics::*;
        private import Components::*;
        private import Behaviors::*;
        private import Requirements::*;
        
        part pumpingSubsystem {
            
            part sourceReservoir : Reservoir {
                attribute :>> capacity = 10000.0;
                attribute :>> currentLevel = 8000.0;
                item :>> storedFluid : Fluid {
                    attribute :>> density : Density {
                        attribute :>> num = 1000.0;
                        attribute :>> unit = "kg/m^3";
                    }
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 293.15;
                }
            }
            
            part pumpDriveMotor : Motor {
                attribute :>> ratedPower : Power {
                    attribute :>> num = 20000.0;
                    attribute :>> unit = "W";
                }
                attribute :>> efficiency : Efficiency {
                    attribute :>> num = 0.93;
                }
                attribute :>> operatingSpeed : AngularVelocity {
                    attribute :>> num = 157.08;
                    attribute :>> unit = "rad/s";
                }
            }
            
            part mainPump : CentrifugalPump {
                part :>> impeller {
                    attribute :>> inletRadius : Radius {
                        attribute :>> num = 0.05;
                        attribute :>> unit = "m";
                    }
                    attribute :>> outletRadius : Radius {
                        attribute :>> num = 0.15;
                        attribute :>> unit = "m";
                    }
                    attribute :>> rotationalSpeed : AngularVelocity {
                        attribute :>> num = 157.08;
                        attribute :>> unit = "rad/s";
                    }
                    attribute :>> bladeCount = 8;
                    attribute :>> bladeAngle = 25.0;
                }
                
                attribute :>> hydraulicEfficiency : Efficiency {
                    attribute :>> num = 0.82;
                }
                attribute :>> mechanicalEfficiency : Efficiency {
                    attribute :>> num = 0.95;
                }
                attribute :>> volumetricEfficiency : Efficiency {
                    attribute :>> num = 0.98;
                }
                
                perform action pumpCycle : PumpingCycle;
                exhibit state pumpStates : PumpOperatingStates;
            }
            
            part pumpDischargeSensor : PressureSensor;
            part pumpFlowMeter : FlowMeter;
            
            part intermediateReservoir : DischargeReservoir {
                attribute :>> capacity = 5000.0;
                attribute :>> currentLevel = 3000.0;
                item :>> storedFluid : Fluid {
                    attribute :>> density : Density {
                        attribute :>> num = 1000.0;
                        attribute :>> unit = "kg/m^3";
                    }
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 293.15;
                }
            }
            
            part turbineInletSensor : PressureSensor;
            part turbineFlowMeter : FlowMeter;
            
            part hydraulicTurbine : HydraulicTurbine {
                part :>> runner {
                    attribute :>> inletRadius : Radius {
                        attribute :>> num = 0.20;
                        attribute :>> unit = "m";
                    }
                    attribute :>> outletRadius : Radius {
                        attribute :>> num = 0.10;
                        attribute :>> unit = "m";
                    }
                    attribute :>> rotationalSpeed : AngularVelocity {
                        attribute :>> num = 104.72;
                        attribute :>> unit = "rad/s";
                    }
                    attribute :>> bladeCount = 12;
                    attribute :>> bladeAngle = 35.0;
                }
                
                attribute :>> hydraulicEfficiency : Efficiency {
                    attribute :>> num = 0.88;
                }
                attribute :>> mechanicalEfficiency : Efficiency {
                    attribute :>> num = 0.97;
                }
                
                perform action turbineCycle : TurbineCycle;
                exhibit state turbineStates : TurbineOperatingStates;
            }
            
            part turbineGenerator : Generator {
                attribute :>> ratedPower : Power {
                    attribute :>> num = 15000.0;
                    attribute :>> unit = "W";
                }
                attribute :>> efficiency : Efficiency {
                    attribute :>> num = 0.95;
                }
                attribute :>> operatingSpeed : AngularVelocity {
                    attribute :>> num = 104.72;
                    attribute :>> unit = "rad/s";
                }
            }
            
            part dischargeReservoir : DischargeReservoir {
                attribute :>> capacity = 8000.0;
                attribute :>> currentLevel = 2000.0;
                item :>> storedFluid : Fluid {
                    attribute :>> density : Density {
                        attribute :>> num = 1000.0;
                        attribute :>> unit = "kg/m^3";
                    }
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 293.15;
                }
            }
            
            flow of fluid : Fluid
                from sourceReservoir.outletPort.fluid
                to mainPump.inletPort.fluid;
            
            connect sourceReservoir.outletPort to mainPump.inletPort;
            
            flow of fluid : Fluid
                from mainPump.outletPort.fluid
                to pumpDischargeSensor.sensingPort.fluid;
            
            connect mainPump.outletPort to pumpDischargeSensor.sensingPort;
            
            flow of fluid : Fluid
                from pumpDischargeSensor.sensingPort.fluid
                to pumpFlowMeter.sensingPort.fluid;
            
            connect pumpDischargeSensor.sensingPort to pumpFlowMeter.sensingPort;
            
            flow of fluid : Fluid
                from pumpFlowMeter.sensingPort.fluid
                to intermediateReservoir.inletPort.fluid;
            
            connect pumpFlowMeter.sensingPort to intermediateReservoir.inletPort;
            
            flow of fluid : Fluid
                from intermediateReservoir.outletPort.fluid
                to turbineInletSensor.sensingPort.fluid;
            
            connect intermediateReservoir.outletPort to turbineInletSensor.sensingPort;
            
            flow of fluid : Fluid
                from turbineInletSensor.sensingPort.fluid
                to turbineFlowMeter.sensingPort.fluid;
            
            connect turbineInletSensor.sensingPort to turbineFlowMeter.sensingPort;
            
            flow of fluid : Fluid
                from turbineFlowMeter.sensingPort.fluid
                to hydraulicTurbine.inletPort.fluid;
            
            connect turbineFlowMeter.sensingPort to hydraulicTurbine.inletPort;
            
            flow of fluid : Fluid
                from hydraulicTurbine.outletPort.fluid
                to dischargeReservoir.inletPort.fluid;
            
            connect hydraulicTurbine.outletPort to dischargeReservoir.inletPort;
            
            connect pumpDriveMotor.powerOutput to mainPump.drivePort;
            connect hydraulicTurbine.outputPort to turbineGenerator.powerInput;
            
            satisfy pumpPerformanceReq : PumpPerformanceRequirement by mainPump;
            satisfy turbinePerformanceReq : TurbinePerformanceRequirement by hydraulicTurbine;
            satisfy eulerComplianceReq : EulerEquationCompliance by pumpingSubsystem;
            satisfy safetyReq : SystemSafetyRequirement by pumpingSubsystem;
        }
    }
}
