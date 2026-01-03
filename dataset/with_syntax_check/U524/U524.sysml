package InductivePumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Units {
        attribute def LitersPerSecond;
        attribute def Pascal;
        attribute def Volt;
        attribute def Ampere;
        attribute def Hertz;
        attribute def Celsius;
        attribute def Siemens;
    }
    
    package Definitions {
        item def ConductiveFluid {
            attribute density : Real;
            attribute temperature : Real;
            attribute electricalConductivity : Real;
        }
        
        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def CurrentValue :> Real;
        attribute def FrequencyValue :> Real;
        attribute def TemperatureValue :> Real;
        
        enum def PumpState {
            enum idle;
            enum starting;
            enum running;
            enum stopping;
            enum faulted;
        }
        
        port def FluidPort {
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            out item fluid : ConductiveFluid;
        }
        
        port def PowerPort {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute frequency : FrequencyValue;
        }
        
        port def ControlPort {
            in attribute commandedFlowRate : FlowRateValue;
            in attribute startCommand : Boolean;
            in attribute stopCommand : Boolean;
            out attribute actualFlowRate : FlowRateValue;
            out attribute status : PumpState;
        }
        
        part def SourceReservoir {
            doc /*
             * Reservoir containing conductive fluid to be pumped.
             */
            attribute capacity : Real;
            attribute currentLevel : Real;
            port outletPort : FluidPort;
            item storedFluid : ConductiveFluid {
                attribute volume : Real;
            }
        }
        
        part def DestinationTank {
            doc /*
             * Receiving tank for pumped fluid.
             */
            attribute capacity : Real;
            attribute currentLevel : Real;
            port inletPort : ~FluidPort;
            item receivedFluid : ConductiveFluid {
                attribute volume : Real;
            }
        }
        
        part def InductivePump {
            doc /*
             * Electromagnetic induction pump that moves conductive fluids
             * without mechanical moving parts. Uses traveling magnetic field
             * to induce eddy currents in the fluid, creating Lorentz force
             * that propels the fluid through the duct.
             */
            
            attribute ratedFlowRate : FlowRateValue;
            attribute maxPressure : PressureValue;
            attribute efficiency : Real;
            attribute coilTemperature : TemperatureValue;
            attribute currentState : PumpState;
            
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port powerInput : ~PowerPort;
            port controlInterface : ControlPort;
            
            part electromagneticCoils {
                attribute numberOfPhases : Integer = 3;
                attribute coilResistance : Real;
                attribute inductance : Real;
                attribute phaseACurrent : CurrentValue;
                attribute phaseBCurrent : CurrentValue;
                attribute phaseCCurrent : CurrentValue;
            }
            
            part magneticCore {
                attribute material : String = "Laminated Silicon Steel";
                attribute relativePermeability : Real;
            }
            
            part pumpDuct {
                attribute innerDiameter : Real;
                attribute length : Real;
                attribute wallThickness : Real;
                attribute material : String = "Stainless Steel 316";
            }
            
            part coolingSystem {
                attribute coolantFlowRate : FlowRateValue;
                attribute coolantTemperature : TemperatureValue;
            }
            
            part temperatureSensor {
                attribute measuredTemperature : TemperatureValue;
            }
            
            exhibit state pumpStateMachine : PumpStateMachine;
            perform action pumpOperation : PumpFluidAction;
        }
        
        part def PowerSupply {
            doc /*
             * Three-phase variable frequency power supply for inductive pump.
             */
            attribute inputVoltage : VoltageValue;
            attribute outputVoltage : VoltageValue;
            attribute maxCurrent : CurrentValue;
            attribute outputFrequency : FrequencyValue;
            
            port powerOutput : PowerPort;
            port controlInput {
                in attribute frequencySetpoint : FrequencyValue;
            }
        }
        
        part def FlowSensor {
            doc /*
             * Measures fluid flow rate and pressure.
             */
            port sensingPort : ~FluidPort;
            port dataOutput {
                out attribute measuredFlowRate : FlowRateValue;
                out attribute measuredPressure : PressureValue;
            }
        }
        
        part def PumpController {
            doc /*
             * Controls pump operation using PID feedback control.
             */
            attribute controlLoopFrequency : FrequencyValue;
            attribute pidProportionalGain : Real;
            attribute pidIntegralGain : Real;
            attribute pidDerivativeGain : Real;
            
            port pumpControl : ~ControlPort;
            port flowFeedback {
                in attribute measuredFlowRate : FlowRateValue;
            }
            port pressureFeedback {
                in attribute inletPressure : PressureValue;
                in attribute outletPressure : PressureValue;
            }
            port powerControl {
                out attribute frequencyCommand : FrequencyValue;
            }
            
            perform action controlLoop : ControlPumpAction;
        }
        
        action def PumpFluidAction {
            doc /*
             * Action representing the electromagnetic pumping process.
             */
            in attribute inputPressure : PressureValue;
            in attribute commandedFlow : FlowRateValue;
            in attribute appliedVoltage : VoltageValue;
            in attribute appliedFrequency : FrequencyValue;
            out attribute outputPressure : PressureValue;
            out attribute actualFlow : FlowRateValue;
            
            first start;
            
            then action generateMagneticField {
                in attribute voltage : VoltageValue = appliedVoltage;
                in attribute frequency : FrequencyValue = appliedFrequency;
                out attribute fieldStrength : Real;
            }
            
            then action induceCurrents {
                in attribute fieldStrength : Real = generateMagneticField.fieldStrength;
                in attribute fluidConductivity : Real;
                out attribute inducedCurrentDensity : Real;
            }
            
            then action generateLorentzForce {
                in attribute currentDensity : Real = induceCurrents.inducedCurrentDensity;
                in attribute magneticFluxDensity : Real;
                out attribute forceDensity : Real;
            }
            
            then action accelerateFluid {
                in attribute force : Real = generateLorentzForce.forceDensity;
                in attribute fluidDensity : Real;
                out attribute flowRate : FlowRateValue;
                out attribute pressureRise : PressureValue;
            }
            
            then done;
        }
        
        action def ControlPumpAction {
            doc /*
             * PID control loop for maintaining desired flow rate.
             */
            in attribute setpoint : FlowRateValue;
            in attribute measuredFlow : FlowRateValue;
            out attribute controlSignal : FrequencyValue;
            
            first start;
            then merge controlLoop;
            
            then action readSensors {
                out currentFlow : FlowRateValue = measuredFlow;
            }
            
            then action calculateError {
                in targetFlow : FlowRateValue = setpoint;
                in actualFlow : FlowRateValue = readSensors.currentFlow;
                out error : Real;
            }
            
            then action computePID {
                in errorValue : Real = calculateError.error;
                out pidOutput : Real;
            }
            
            then action updateFrequency {
                in controlValue : Real = computePID.pidOutput;
                out frequency : FrequencyValue;
            }
            
            then controlLoop;
        }
        
        state def PumpStateMachine {
            doc /*
             * State machine controlling pump operational states.
             */
            
            entry; then idle;
            
            state idle;
            
            transition idle_to_starting
                first idle
                accept startCommand
                then starting;
            
            state starting {
                do action rampUpSpeed {
                    out targetFrequency : FrequencyValue;
                }
            }
            
            transition starting_to_running
                first starting
                if coilTemperature < 80.0
                then running;
            
            transition starting_to_faulted
                first starting
                if coilTemperature >= 80.0
                then faulted;
            
            state running {
                do action maintainOperation;
            }
            
            transition running_to_stopping
                first running
                accept stopCommand
                then stopping;
            
            transition running_to_faulted
                first running
                if coilTemperature >= 90.0
                then faulted;
            
            state stopping {
                do action rampDownSpeed;
            }
            
            transition stopping_to_idle
                first stopping
                then idle;
            
            state faulted;
            
            transition faulted_to_idle
                first faulted
                if coilTemperature < 60.0
                then idle;
        }
    }
    
    package Usages {
        part pumpingSystem {
            doc /*
             * Complete inductive pumping subsystem for transferring
             * conductive fluid from source to destination.
             */
            
            part sourceReservoir : SourceReservoir {
                attribute :>> capacity = 2000.0;
                attribute :>> currentLevel = 1500.0;
                
                item :>> storedFluid {
                    attribute :>> volume = 1500.0;
                    attribute :>> density = 1200.0;
                    attribute :>> temperature = 25.0;
                    attribute :>> electricalConductivity = 5.0e6;
                }
            }
            
            flow of fluid : ConductiveFluid
                from sourceReservoir.outletPort.fluid to inletSensor.sensingPort.fluid;
            
            part inletSensor : FlowSensor;
            
            flow of fluid : ConductiveFluid
                from inletSensor.sensingPort.fluid to pump.inletPort.fluid;
            
            part pump : InductivePump {
                attribute :>> ratedFlowRate = 50.0;
                attribute :>> maxPressure = 1000000.0;
                attribute :>> efficiency = 0.85;
                attribute :>> coilTemperature = 45.0;
                attribute :>> currentState = PumpState::idle;
                
                part :>> electromagneticCoils {
                    attribute :>> numberOfPhases = 3;
                    attribute :>> coilResistance = 0.5;
                    attribute :>> inductance = 0.02;
                }
                
                part :>> pumpDuct {
                    attribute :>> innerDiameter = 0.15;
                    attribute :>> length = 0.8;
                    attribute :>> wallThickness = 0.005;
                }
                
                part :>> coolingSystem {
                    attribute :>> coolantFlowRate = 10.0;
                    attribute :>> coolantTemperature = 20.0;
                }
            }
            
            flow of fluid : ConductiveFluid
                from pump.outletPort.fluid to outletSensor.sensingPort.fluid;
            
            part outletSensor : FlowSensor;
            
            flow of fluid : ConductiveFluid
                from outletSensor.sensingPort.fluid to destinationTank.inletPort.fluid;
            
            part destinationTank : DestinationTank {
                attribute :>> capacity = 2000.0;
                attribute :>> currentLevel = 0.0;
            }
            
            part powerSupply : PowerSupply {
                attribute :>> inputVoltage = 480.0;
                attribute :>> outputVoltage = 380.0;
                attribute :>> maxCurrent = 100.0;
                attribute :>> outputFrequency = 60.0;
            }
            
            connect pump.powerInput to powerSupply.powerOutput;
            
            part controller : PumpController {
                attribute :>> controlLoopFrequency = 100.0;
                attribute :>> pidProportionalGain = 0.5;
                attribute :>> pidIntegralGain = 0.1;
                attribute :>> pidDerivativeGain = 0.05;
            }
            
            connect controller.pumpControl to pump.controlInterface;
            
            bind controller.flowFeedback.measuredFlowRate = outletSensor.dataOutput.measuredFlowRate;
            bind controller.pressureFeedback.inletPressure = inletSensor.dataOutput.measuredPressure;
            bind controller.pressureFeedback.outletPressure = outletSensor.dataOutput.measuredPressure;
            bind powerSupply.controlInput.frequencySetpoint = controller.powerControl.frequencyCommand;
        }
    }
    
    package Requirements {
        requirement flowRateRequirement {
            doc /*
             * The pumping subsystem shall maintain commanded flow rate
             * within 5% tolerance during steady-state operation.
             */
            
            subject pumpingSystem : pumpingSystem;
            
            require constraint {
                pumpingSystem.pump.controlInterface.actualFlowRate >= 
                    0.95 * pumpingSystem.pump.controlInterface.commandedFlowRate and
                pumpingSystem.pump.controlInterface.actualFlowRate <= 
                    1.05 * pumpingSystem.pump.controlInterface.commandedFlowRate
            }
        }
        
        requirement pressureRequirement {
            doc /*
             * The pump shall generate minimum pressure rise of 5 bar
             * at rated flow conditions.
             */
            
            subject pump : InductivePump;
            
            require constraint {
                pump.outletPort.pressure >= pump.inletPort.pressure + 500000.0
            }
        }
        
        requirement efficiencyRequirement {
            doc /*
             * The inductive pump shall operate at minimum 80% efficiency
             * at rated conditions.
             */
            
            subject pump : InductivePump;
            
            require constraint {
                pump.efficiency >= 0.80
            }
        }
        
        requirement temperatureRequirement {
            doc /*
             * Pump coil temperature shall not exceed 85 degrees Celsius
             * during continuous operation.
             */
            
            subject pump : InductivePump;
            
            require constraint {
                pump.coilTemperature <= 85.0
            }
        }
        
        requirement fluidConductivityRequirement {
            doc /*
             * Fluid must have minimum electrical conductivity of
             * 1.0e6 Siemens for effective inductive pumping.
             */
            
            subject fluid : ConductiveFluid;
            
            require constraint {
                fluid.electricalConductivity >= 1.0e6
            }
        }
        
        requirement systemReliabilityRequirement {
            doc /*
             * The pumping subsystem shall automatically shut down
             * and enter fault state if coil temperature exceeds safe limits.
             */
            
            subject pump : InductivePump;
            
            require constraint {
                pump.coilTemperature >= 90.0 implies pump.currentState == PumpState::faulted
            }
        }
    }
}
