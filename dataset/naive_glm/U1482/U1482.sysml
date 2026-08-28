package RefrigerationSystem {
    import ScalarValues::*;

    package Units {
        value def Kelvin :> Real { unit "K"; }
        value def Pascal :> Real { unit "Pa"; }
        value def KilogramPerSecond :> Real { unit "kg/s"; }
        value def Watt :> Real { unit "W"; }
        value def Hertz :> Real { unit "Hz"; }
        value def Second :> Real { unit "s"; }
        value def JoulePerKilogram :> Real { unit "J/kg"; }
        value def SquareMeter :> Real { unit "m^2"; }
        value def CubicMeter :> Real { unit "m^3"; }
        value def JoulePerKelvin :> Real { unit "J/K"; }
        value def Kilogram :> Real { unit "kg"; }
        value def Volt :> Real { unit "V"; }
        value def Ampere :> Real { unit "A"; }
        value def Dimensionless :> Real { unit "1"; }
    }

    package ValueTypes {
        import Units::*;
        value def Temperature :> Real { unit Kelvin; }
        value def Pressure :> Real { unit Pascal; }
        value def MassFlowRate :> Real { unit KilogramPerSecond; }
        value def Power :> Real { unit Watt; }
        value def RotationalSpeed :> Real { unit Hertz; }
        value def Duration :> Real { unit Second; }
        value def Enthalpy :> Real { unit JoulePerKilogram; }
        value def Area :> Real { unit SquareMeter; }
        value def Volume :> Real { unit CubicMeter; }
        value def ThermalMass :> Real { unit JoulePerKelvin; }
        value def Mass :> Real { unit Kilogram; }
        value def Voltage :> Real { unit Volt; }
        value def Current :> Real { unit Ampere; }
        value def CoefficientOfPerformance :> Real { unit Dimensionless; }
        value def Quality :> Real { unit Dimensionless; }
    }

    package Refrigerant {
        import ValueTypes::*;

        item def RefrigerantState {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute enthalpy : Enthalpy;
            attribute massFlowRate : MassFlowRate;
            attribute quality : Quality;
        }

        item def RefrigerantVapor :> RefrigerantState {
            attribute quality : Quality = 1.0;
        }

        item def RefrigerantLiquid :> RefrigerantState {
            attribute quality : Quality = 0.0;
        }

        item def RefrigerantMixture :> RefrigerantState;

        item def CompressorInletVapor :> RefrigerantVapor;
        item def CompressorDischargeGas :> RefrigerantVapor;
        item def CondenserOutletLiquid :> RefrigerantLiquid;
        item def ExpansionOutletMixture :> RefrigerantMixture;
        item def EvaporatorOutletVapor :> RefrigerantVapor;
    }

    package Ports {
        import Refrigerant::*;
        import ValueTypes::*;

        port def RefrigerantPort {
            attribute pressure : Pressure;
            attribute temperature : Temperature;
            attribute massFlowRate : MassFlowRate;
            attribute quality : Quality;
            in item : RefrigerantState;
            out item : RefrigerantState;
        }

        port def ElectricalPowerPort {
            attribute voltage : Voltage;
            attribute current : Current;
            attribute power : Power;
            in flow : Power;
        }

        port def ControlSignalPort {
            attribute speedCommand : RotationalSpeed;
            attribute command : Real;
            in signal : Real;
        }

        port def TemperatureSignalPort {
            attribute measuredTemperature : Temperature;
            out signal : Temperature;
        }

        port def HeatTransferPort {
            attribute heatFlow : Power;
            out flow : Power;
        }

        port def DefrostSignalPort {
            attribute defrostActive : Boolean;
            in signal : Boolean;
        }
    }

    package Components {
        import Ports::*;
        import Refrigerant::*;
        import ValueTypes::*;

        part def Compressor {
            attribute nominalPower : Power = 500 [W];
            attribute maxSpeed : RotationalSpeed = 60 [Hz];
            attribute minSpeed : RotationalSpeed = 0 [Hz];
            attribute currentSpeed : RotationalSpeed = 0 [Hz];
            attribute isRunning : Boolean = false;
            attribute powerConsumption : Power = 0 [W];
            attribute compressionRatio : Real = 8.0;
            attribute volumetricEfficiency : Real = 0.85;

            port inlet : RefrigerantPort;
            port outlet : RefrigerantPort;
            port powerIn : ElectricalPowerPort;
            port speedCommand : ControlSignalPort;

            action def Compress {
                in vaporIn : CompressorInletVapor;
                out gasOut : CompressorDischargeGas;
                in speed : RotationalSpeed;
            }

            perform action compress : Compress;
        }

        part def Condenser {
            attribute heatTransferArea : Area = 0.5 [m^2];
            attribute fanSpeed : RotationalSpeed = 30 [Hz];
            attribute heatRejectionRate : Power = 0 [W];
            attribute subcooling : Temperature = 5 [K];

            port inlet : RefrigerantPort;
            port outlet : RefrigerantPort;
            port heatOut : HeatTransferPort;

            action def Condense {
                in gasIn : CompressorDischargeGas;
                out liquidOut : CondenserOutletLiquid;
                out heatRejected : Power;
            }

            perform action condense : Condense;
        }

        part def ExpansionValve {
            attribute orificeDiameter : Real { unit "m"; } = 0.001;
            attribute pressureDrop : Pressure = 1800000 [Pa];
            attribute openingFraction : Real = 1.0;

            port inlet : RefrigerantPort;
            port outlet : RefrigerantPort;

            action def Expand {
                in liquidIn : CondenserOutletLiquid;
                out mixtureOut : ExpansionOutletMixture;
            }

            perform action expand : Expand;
        }

        part def Evaporator {
            attribute heatTransferArea : Area = 0.4 [m^2];
            attribute coolingCapacity : Power = 0 [W];
            attribute frostAccumulation : Mass = 0 [kg];
            attribute defrostNeeded : Boolean = false;
            attribute superheat : Temperature = 5 [K];

            port inlet : RefrigerantPort;
            port outlet : RefrigerantPort;
            port heatIn : HeatTransferPort;
            port defrostIn : DefrostSignalPort;

            action def Evaporate {
                in mixtureIn : ExpansionOutletMixture;
                out vaporOut : EvaporatorOutletVapor;
                in heatAbsorbed : Power;
            }

            action def Defrost {
                in heaterPower : Power;
                out meltedFrost : Mass;
            }

            perform action evaporate : Evaporate;
            perform action defrost : Defrost;
        }

        part def TemperatureSensor {
            attribute accuracy : Temperature = 0.5 [K];
            attribute samplingRate : Real { unit "Hz"; } = 1;
            attribute measuredTemperature : Temperature = 277.15 [K];

            port tempOut : TemperatureSignalPort;

            action def Measure {
                out temperature : Temperature;
            }

            perform action measure : Measure;
        }

        part def Controller {
            attribute setpoint : Temperature = 277.15 [K];
            attribute tolerance : Temperature = 1.0 [K];
            attribute defrostInterval : Duration = 21600 [s];
            attribute defrostDuration : Duration = 600 [s];
            attribute lastDefrostTime : Duration = 0 [s];
            attribute currentMode : String = "Off";
            attribute kp : Real = 2.0;
            attribute ki : Real = 0.5;
            attribute integralError : Real = 0;
            attribute powerOn : Boolean = true;
            attribute defrostDurationElapsed : Boolean = false;

            port tempIn : TemperatureSignalPort;
            port compressorCommand : ControlSignalPort;
            port defrostSignal : DefrostSignalPort;

            action def ComputeSpeed {
                in measuredTemp : Temperature;
                in setpointTemp : Temperature;
                out speed : RotationalSpeed;
            }

            perform action computeSpeed : ComputeSpeed;

            state machine def ControllerStateMachine {
                attribute mode : String;

                state Off {
                    entry assign mode = "Off";
                    entry assign compressorCommand.speedCommand = 0 [Hz];
                }

                state Idle {
                    entry assign mode = "Idle";
                    entry assign compressorCommand.speedCommand = 0 [Hz];
                }

                state Cooling {
                    entry assign mode = "Cooling";
                }

                state Defrost {
                    entry assign mode = "Defrost";
                    entry assign defrostSignal.defrostActive = true;
                    exit assign defrostSignal.defrostActive = false;
                }

                transition off_to_idle
                    first Off to Idle
                    when powerOn == true;

                transition idle_to_cooling
                    Idle to Cooling
                    when tempIn.measuredTemperature > (setpoint + tolerance);

                transition cooling_to_idle
                    Cooling to Idle
                    when tempIn.measuredTemperature <= (setpoint - tolerance);

                transition idle_to_defrost
                    Idle to Defrost
                    when defrostNeeded == true;

                transition cooling_to_defrost
                    Cooling to Defrost
                    when defrostNeeded == true;

                transition defrost_to_idle
                    Defrost to Idle
                    when defrostDurationElapsed == true;

                transition idle_to_off
                    Idle to Off
                    when powerOn == false;

                transition cooling_to_off
                    Cooling to Off
                    when powerOn == false;

                transition defrost_to_off
                    Defrost to Off
                    when powerOn == false;
            }

            perform state machine controllerSM : ControllerStateMachine;
        }

        part def PowerSource {
            attribute supplyVoltage : Voltage = 230 [V];
            attribute maxCurrent : Current = 10 [A];
            attribute availablePower : Power = 2300 [W];

            port powerOut : ElectricalPowerPort;
        }
    }

    package System {
        import Components::*;
        import Ports::*;
        import Refrigerant::*;
        import ValueTypes::*;

        part def CooledCompartment {
            attribute volume : Volume = 0.5 [m^3];
            attribute currentTemperature : Temperature = 298.15 [K];
            attribute targetTemperature : Temperature = 277.15 [K];
            attribute thermalMass : ThermalMass = 50000 [J/K];
            attribute heatLeakageRate : Power = 30 [W];

            port heatAbsorption : HeatTransferPort;
        }

        part def Environment {
            attribute ambientTemperature : Temperature = 298.15 [K];
            attribute ambientPressure : Pressure = 101325 [Pa];

            port heatRejection : HeatTransferPort;
        }

        part def RefrigerationSystem {
            attribute systemPower : Power = 0 [W];
            attribute coolingCapacity : Power = 0 [W];
            attribute cop : CoefficientOfPerformance = 0;
            attribute powerOn : Boolean = true;
            attribute defrostNeeded : Boolean = false;
            attribute defrostDurationElapsed : Boolean = false;
            attribute operatingTime : Duration = 0 [s];

            part compressor : Compressor;
            part condenser : Condenser;
            part expansionValve : ExpansionValve;
            part evaporator : Evaporator;
            part temperatureSensor : TemperatureSensor;
            part controller : Controller;
            part compartment : CooledCompartment;
            part environment : Environment;
            part powerSource : PowerSource;

            connection refrigerantFlow1 connect compressor.outlet to condenser.inlet;
            connection refrigerantFlow2 connect condenser.outlet to expansionValve.inlet;
            connection refrigerantFlow3 connect expansionValve.outlet to evaporator.inlet;
            connection refrigerantFlow4 connect evaporator.outlet to compressor.inlet;

            connection heatRejection connect condenser.heatOut to environment.heatRejection;
            connection heatAbsorption connect compartment.heatAbsorption to evaporator.heatIn;

            connection tempFeedback connect temperatureSensor.tempOut to controller.tempIn;
            connection compressorControl connect controller.compressorCommand to compressor.speedCommand;
            connection defrostControl connect controller.defrostSignal to evaporator.defrostIn;

            connection powerSupply connect powerSource.powerOut to compressor.powerIn;

            allocation controller.powerOn = powerOn;
            allocation controller.defrostNeeded = evaporator.defrostNeeded;
            allocation controller.defrostDurationElapsed = defrostDurationElapsed;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import System::*;

        requirement def CoolingCapacityRequirement {
            attribute minCoolingCapacity : Power = 200 [W];
            subject system : RefrigerationSystem;
            require { system.coolingCapacity >= minCoolingCapacity; }
        }

        requirement def TemperatureControlRequirement {
            attribute setpoint : Temperature = 277.15 [K];
            attribute tolerance : Temperature = 1.0 [K];
            subject system : RefrigerationSystem;
            require { abs(system.compartment.currentTemperature - setpoint) <= tolerance; }
        }

        requirement def EfficiencyRequirement {
            attribute minCOP : CoefficientOfPerformance = 2.5;
            subject system : RefrigerationSystem;
            require { system.cop >= minCOP; }
        }

        requirement def PressureSafetyRequirement {
            attribute maxDischargePressure : Pressure = 2500000 [Pa];
            attribute minSuctionPressure : Pressure = 100000 [Pa];
            subject system : RefrigerationSystem;
            require { system.compressor.outlet.pressure <= maxDischargePressure; }
            require { system.evaporator.outlet.pressure >= minSuctionPressure; }
        }

        requirement def TemperatureSafetyRequirement {
            attribute maxDischargeTemp : Temperature = 373.15 [K];
            attribute minEvapTemp : Temperature = 233.15 [K];
            subject system : RefrigerationSystem;
            require { system.compressor.outlet.temperature <= maxDischargeTemp; }
            require { system.evaporator.inlet.temperature >= minEvapTemp; }
        }

        requirement def DefrostRequirement {
            attribute maxFrostAccumulation : Mass = 0.1 [kg];
            subject system : RefrigerationSystem;
            require { system.evaporator.frostAccumulation <= maxFrostAccumulation; }
        }

        requirement def PowerLimitRequirement {
            attribute maxPower : Power = 800 [W];
            subject system : RefrigerationSystem;
            require { system.compressor.powerConsumption <= maxPower; }
        }

        requirement def SystemRequirements {
            requirement coolingCap : CoolingCapacityRequirement;
            requirement tempControl : TemperatureControlRequirement;
            requirement efficiency : EfficiencyRequirement;
            requirement pressureSafety : PressureSafetyRequirement;
            requirement tempSafety : TemperatureSafetyRequirement;
            requirement defrost : DefrostRequirement;
            requirement powerLimit : PowerLimitRequirement;
        }
    }
}
