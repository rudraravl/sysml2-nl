package 'Stirling Engine System' {
    private import SI::*;
    private import ISQ::*;

    package Definitions {
        port def HeatPort {
            attribute temperature : ISQ::thermodynamicTemperature;
            attribute heatRate : ISQ::power;
        }

        port def LinearMechPort {
            attribute force : ISQ::force;
        }

        port def RotaryMechPort {
            attribute torque : ISQ::torque;
            attribute angularVelocity : ISQ::angularVelocity;
        }

        port def GasPort {
            attribute pressure : ISQ::pressure;
            attribute temperature : ISQ::thermodynamicTemperature;
        }

        item def Heat;
        item def LinearForce;
        item def RotaryPower;

        item def WorkingGas {
            attribute mass : ISQ::mass;
            attribute temperature : ISQ::thermodynamicTemperature;
            attribute pressure : ISQ::pressure;
            attribute volume : ISQ::volume;
        }

        flow def ThermalFlow {
            ref :>> payload : Heat;
            end port sourcePort : HeatPort;
            end port destPort : HeatPort;
        }

        flow def LinearMechFlow {
            ref :>> payload : LinearForce;
            end port sourcePort : LinearMechPort;
            end port destPort : LinearMechPort;
        }

        flow def RotaryMechFlow {
            ref :>> payload : RotaryPower;
            end port sourcePort : RotaryMechPort;
            end port destPort : RotaryMechPort;
        }

        flow def GasFlow {
            ref :>> payload : WorkingGas;
            end port portA : GasPort;
            end port portB : GasPort;
        }

        attribute def EngineStart;
        attribute def EngineStop;

        part def HeatSource {
            port heatOut : HeatPort;
            attribute outputTemperature : ISQ::thermodynamicTemperature;
        }

        part def HeatSink {
            port heatIn : HeatPort;
            attribute sinkTemperature : ISQ::thermodynamicTemperature;
        }

        part def ExpansionChamber {
            port heatPort : HeatPort;
            port gasPort : GasPort;
            attribute volume : ISQ::volume;
            attribute wallTemperature : ISQ::thermodynamicTemperature;
        }

        part def CompressionChamber {
            port heatPort : HeatPort;
            port gasPort : GasPort;
            attribute volume : ISQ::volume;
            attribute wallTemperature : ISQ::thermodynamicTemperature;
        }

        part def DisplacerPiston {
            port hotGasPort : GasPort;
            port coldGasPort : GasPort;
            attribute strokeLength : ISQ::length;
        }

        part def PowerPiston {
            port gasPort : GasPort;
            port mechPort : LinearMechPort;
            attribute boreDiameter : ISQ::length;
            attribute strokeLength : ISQ::length;
        }

        part def Regenerator {
            port hotGasPort : GasPort;
            port coldGasPort : GasPort;
            attribute heatCapacity : ISQ::energy;
            attribute effectiveness : ScalarValues::Real;
        }

        part def Crankshaft {
            port linearIn : LinearMechPort;
            port rotaryOut : RotaryMechPort;
            attribute crankRadius : ISQ::length;
        }

        part def Flywheel {
            port rotaryIn : RotaryMechPort;
            port rotaryOut : RotaryMechPort;
            attribute momentOfInertia : ISQ::momentOfInertia;
        }

        part def StirlingEngine {
            port heatInPort : HeatPort;
            port heatOutPort : HeatPort;
            port powerOutPort : RotaryMechPort;
            attribute workingGasMass : ISQ::mass;

            part expansionChamber : ExpansionChamber;
            part compressionChamber : CompressionChamber;
            part displacerPiston : DisplacerPiston;
            part powerPiston : PowerPiston;
            part regenerator : Regenerator;
            part crankshaft : Crankshaft;
            part flywheel : Flywheel;
        }

        action def HeatWorkingGas {
            in workingGas : WorkingGas;
            in heatInput : ISQ::energy;
            out heatedGas : WorkingGas;
        }

        action def ExpandWorkingGas {
            in heatedGas : WorkingGas;
            out expandedGas : WorkingGas;
            out linearForce : ISQ::force;
        }

        action def CoolWorkingGas {
            in expandedGas : WorkingGas;
            out heatRejected : ISQ::energy;
            out cooledGas : WorkingGas;
        }

        action def CompressWorkingGas {
            in cooledGas : WorkingGas;
            in linearForce : ISQ::force;
            out compressedGas : WorkingGas;
        }

        action def StirlingCycle {
            in heatInput : ISQ::energy;
            out heatRejected : ISQ::energy;
            out outputTorque : ISQ::torque;
        }

        state machine def EngineOperation {
            state heating;
            state expanding;
            state cooling;
            state compressing;
            transition from heating to expanding;
            transition from expanding to cooling;
            transition from cooling to compressing;
            transition from compressing to heating;
        }

        requirement def PowerOutputRequirement {
            subject engine : StirlingEngine;
            attribute requiredPower : ISQ::power;
            attribute actualPower : ISQ::power;
            require constraint { actualPower >= requiredPower }
        }

        requirement def ThermalEfficiencyRequirement {
            subject engine : StirlingEngine;
            attribute requiredEfficiency : ScalarValues::Real;
            attribute actualEfficiency : ScalarValues::Real;
            require constraint { actualEfficiency >= requiredEfficiency }
        }

        requirement def ContinuousOperationRequirement {
            subject engine : StirlingEngine;
            attribute sourceTemperature : ISQ::thermodynamicTemperature;
            attribute sinkTemperature : ISQ::thermodynamicTemperature;
            require constraint { sourceTemperature > sinkTemperature }
        }
    }

    package Usages {
        private import Definitions::*;

        part stirlingSystem {
            part heatSource : HeatSource {
                attribute outputTemperature : ISQ::thermodynamicTemperature = 923 [K];
            }

            part heatSink : HeatSink {
                attribute sinkTemperature : ISQ::thermodynamicTemperature = 293 [K];
            }

            part engine : StirlingEngine {
                attribute workingGasMass : ISQ::mass = 0.001 [kg];

                part expansionChamber : ExpansionChamber {
                    attribute volume : ISQ::volume = 0.0001 [m^3];
                    attribute wallTemperature : ISQ::thermodynamicTemperature = 923 [K];
                }

                part compressionChamber : CompressionChamber {
                    attribute volume : ISQ::volume = 0.0001 [m^3];
                    attribute wallTemperature : ISQ::thermodynamicTemperature = 293 [K];
                }

                part displacerPiston : DisplacerPiston {
                    attribute strokeLength : ISQ::length = 0.05 [m];
                }

                part powerPiston : PowerPiston {
                    attribute boreDiameter : ISQ::length = 0.06 [m];
                    attribute strokeLength : ISQ::length = 0.05 [m];
                }

                part regenerator : Regenerator {
                    attribute heatCapacity : ISQ::energy = 500 [J];
                    attribute effectiveness : ScalarValues::Real = 0.8;
                }

                part crankshaft : Crankshaft {
                    attribute crankRadius : ISQ::length = 0.025 [m];
                }

                part flywheel : Flywheel {
                    attribute momentOfInertia : ISQ::momentOfInertia = 0.01 [kg*m^2];
                }

                flow : ThermalFlow of Heat
                    from heatInPort to expansionChamber.heatPort;
                flow : ThermalFlow of Heat
                    from compressionChamber.heatPort to heatOutPort;
                flow : GasFlow of WorkingGas
                    from expansionChamber.gasPort to displacerPiston.hotGasPort;
                flow : GasFlow of WorkingGas
                    from displacerPiston.coldGasPort to regenerator.hotGasPort;
                flow : GasFlow of WorkingGas
                    from regenerator.coldGasPort to compressionChamber.gasPort;
                flow : GasFlow of WorkingGas
                    from compressionChamber.gasPort to powerPiston.gasPort;
                flow : LinearMechFlow of LinearForce
                    from powerPiston.mechPort to crankshaft.linearIn;
                flow : RotaryMechFlow of RotaryPower
                    from crankshaft.rotaryOut to flywheel.rotaryIn;
                flow : RotaryMechFlow of RotaryPower
                    from flywheel.rotaryOut to powerOutPort;
            }

            flow : ThermalFlow of Heat
                from heatSource.heatOut to engine.heatInPort;
            flow : ThermalFlow of Heat
                from engine.heatOutPort to heatSink.heatIn;
        }

        action operateEngine : StirlingCycle {
            in heatInput : ISQ::energy;
            out heatRejected : ISQ::energy;
            out outputTorque : ISQ::torque;
            loop {
                accept engineStart : EngineStart;
                then action {
                    action heatGas : HeatWorkingGas {
                        in workingGas : WorkingGas;
                        in heatInput = operateEngine::heatInput;
                        out heatedGas : WorkingGas;
                    }
                    flow heatGas.heatedGas to expandGas.heatedGas;
                    action expandGas : ExpandWorkingGas {
                        in heatedGas : WorkingGas;
                        out expandedGas : WorkingGas;
                        out linearForce : ISQ::force;
                    }
                    flow expandGas.expandedGas to coolGas.expandedGas;
                    action coolGas : CoolWorkingGas {
                        in expandedGas : WorkingGas;
                        out heatRejected : ISQ::energy;
                        out cooledGas : WorkingGas;
                    }
                    flow coolGas.cooledGas to compressGas.cooledGas;
                    action compressGas : CompressWorkingGas {
                        in cooledGas : WorkingGas;
                        in linearForce : ISQ::force;
                        out compressedGas : WorkingGas;
                    }
                    flow compressGas.compressedGas to heatGas.workingGas;
                }
                then accept engineStop : EngineStop;
            }
        }

        requirement stirlingPowerReq : PowerOutputRequirement {
            subject engine : StirlingEngine;
            attribute requiredPower : ISQ::power = 500 [W];
            attribute actualPower : ISQ::power = 550 [W];
        }

        requirement stirlingEfficiencyReq : ThermalEfficiencyRequirement {
            subject engine : StirlingEngine;
            attribute requiredEfficiency : ScalarValues::Real = 0.3;
            attribute actualEfficiency : ScalarValues::Real = 0.35;
        }

        requirement stirlingContinuousReq : ContinuousOperationRequirement {
            subject engine : StirlingEngine;
            attribute sourceTemperature : ISQ::thermodynamicTemperature = 923 [K];
            attribute sinkTemperature : ISQ::thermodynamicTemperature = 293 [K];
        }
    }
}
