package StirlingEngineSystem {
    import ISQ::*;
    import ScalarValues::*;

    value def TemperatureValue :> Real { unit 'K'; }
    value def PressureValue :> Real { unit 'Pa'; }
    value def VolumeValue :> Real { unit 'm^3'; }
    value def EnergyValue :> Real { unit 'J'; }
    value def PowerValue :> Real { unit 'W'; }
    value def TorqueValue :> Real { unit 'N.m'; }
    value def AngularVelocityValue :> Real { unit 'rad/s'; }
    value def ForceValue :> Real { unit 'N'; }
    value def MassValue :> Real { unit 'kg'; }
    value def LengthValue :> Real { unit 'm'; }
    value def HeatFlowRateValue :> Real { unit 'W'; }
    value def RotationalInertiaValue :> Real { unit 'kg.m^2'; }
    value def EfficiencyValue :> Real { unit '%'; }
    value def AreaValue :> Real { unit 'm^2'; }
    value def AngleValue :> Real { unit 'rad'; }

    enum ThermalDirection { toHot; toCold; }

    item def WorkingGas {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute mass : MassValue;
        attribute specificHeatRatio : Real = 1.4;
        attribute gasConstant : Real = 287;
    }

    item def HeatFlow {
        attribute rate : HeatFlowRateValue;
        attribute direction : ThermalDirection;
    }

    item def LinearMotion {
        attribute displacement : LengthValue;
        attribute velocity : LengthValue;
    }

    item def RotationalMotion {
        attribute angle : AngleValue;
        attribute angularVelocity : AngularVelocityValue;
    }

    port def ThermalPort {
        attribute temperature : TemperatureValue;
        out heatFlow : HeatFlow;
    }

    port def FluidPort {
        attribute pressure : PressureValue;
        out gas : WorkingGas;
    }

    port def MechanicalLinearPort {
        attribute force : ForceValue;
        out linearMotion : LinearMotion;
    }

    port def MechanicalRotationalPort {
        attribute torque : TorqueValue;
        attribute angularVelocity : AngularVelocityValue;
        out rotationalMotion : RotationalMotion;
    }

    requirement def ContinuousPowerRequirement {
        subject engine : StirlingEngine;
        objective {
            engine.outputPower >= 500 [W] and
            engine.outputStability >= 90 [%]
        }
    }

    requirement def TemperatureDifferentialRequirement {
        subject engine : StirlingEngine;
        objective {
            engine.heatSourceTemperature - engine.heatSinkTemperature >= 100 [K]
        }
    }

    requirement def EfficiencyRequirement {
        subject engine : StirlingEngine;
        objective {
            engine.thermalEfficiency >= 30 [%]
        }
    }

    requirement def SealedGasRequirement {
        subject engine : StirlingEngine;
        objective {
            engine.workingGas.mass == 0.001 [kg] and
            engine.sealIntegrity == true
        }
    }

    requirement def FlywheelStabilityRequirement {
        subject flywheel : Flywheel;
        objective {
            flywheel.momentOfInertia >= 0.005 [kg.m^2] and
            flywheel.angularVelocity >= 50 [rad/s]
        }
    }

    part def HeatSource {
        port out thermalOutput : ThermalPort;
        attribute outputTemperature : TemperatureValue = 923 [K];
        attribute heatRate : HeatFlowRateValue = 2000 [W];
        attribute fuelType : String = "SolarConcentrated";
    }

    part def HeatSink {
        port in thermalInput : ThermalPort;
        attribute sinkTemperature : TemperatureValue = 293 [K];
        attribute coolingCapacity : HeatFlowRateValue = 1500 [W];
        attribute coolingMedium : String = "AmbientAir";
    }

    part def ExpansionChamber {
        port in heatIn : ThermalPort;
        port out gasOut : FluidPort;
        port in gasReturn : FluidPort;
        attribute volume : VolumeValue = 0.0001 [m^3];
        attribute wallTemperature : TemperatureValue;
        attribute maxTemperature : TemperatureValue = 923 [K];
        attribute heatTransferArea : AreaValue = 0.01 [m^2];
    }

    part def CompressionChamber {
        port out heatOut : ThermalPort;
        port in gasIn : FluidPort;
        port out gasExit : FluidPort;
        attribute volume : VolumeValue = 0.0001 [m^3];
        attribute wallTemperature : TemperatureValue;
        attribute minTemperature : TemperatureValue = 293 [K];
        attribute heatTransferArea : AreaValue = 0.01 [m^2];
    }

    part def Regenerator {
        port in gasFromHot : FluidPort;
        port in gasFromCold : FluidPort;
        port out gasToCold : FluidPort;
        port out gasToHot : FluidPort;
        attribute storedHeat : EnergyValue = 50 [J];
        attribute effectiveness : Real = 0.85;
        attribute matrixMaterial : String = "StainlessSteelMesh";
        attribute matrixPorosity : Real = 0.75;

        action def AbsorbHeat {
            in gasIn : WorkingGas;
            out gasOut : WorkingGas;
        }

        action def ReleaseHeat {
            in gasIn : WorkingGas;
            out gasOut : WorkingGas;
        }
    }

    part def DisplacerPiston {
        port in linearDrive : MechanicalLinearPort;
        port out gasDisplacement : FluidPort;
        attribute stroke : LengthValue = 0.05 [m];
        attribute position : LengthValue;
        attribute phaseAngle : AngleValue = 1.5708 [rad];
        attribute pistonMass : MassValue = 0.2 [kg];
    }

    part def PowerPiston {
        port in gasPressure : FluidPort;
        port out linearForce : MechanicalLinearPort;
        attribute bore : LengthValue = 0.04 [m];
        attribute stroke : LengthValue = 0.05 [m];
        attribute position : LengthValue;
        attribute maxForce : ForceValue = 500 [N];
        attribute pistonArea : AreaValue = 0.001257 [m^2];
    }

    part def Crankshaft {
        port in linearInput : MechanicalLinearPort;
        port out rotationalOutput : MechanicalRotationalPort;
        attribute crankRadius : LengthValue = 0.025 [m];
        attribute currentAngle : AngleValue;
        attribute outputTorque : TorqueValue;
        attribute bearingFriction : Real = 0.002;
    }

    part def Flywheel {
        port in rotationalInput : MechanicalRotationalPort;
        port out rotationalOutput : MechanicalRotationalPort;
        attribute momentOfInertia : RotationalInertiaValue = 0.01 [kg.m^2];
        attribute angularVelocity : AngularVelocityValue;
        attribute dampingCoefficient : Real = 0.001;
        attribute mass : MassValue = 2.0 [kg];
        attribute radius : LengthValue = 0.1 [m];
    }

    part def StirlingEngine {
        port in heatInput : ThermalPort;
        port in heatRejection : ThermalPort;
        port out mechanicalOutput : MechanicalRotationalPort;

        attribute workingGas : WorkingGas {
            temperature = 600 [K];
            pressure = 101325 [Pa];
            mass = 0.001 [kg];
            specificHeatRatio = 1.4;
            gasConstant = 287;
        }

        attribute heatSourceTemperature : TemperatureValue = 923 [K];
        attribute heatSinkTemperature : TemperatureValue = 293 [K];
        attribute outputPower : PowerValue = 500 [W];
        attribute outputStability : EfficiencyValue = 92 [%];
        attribute thermalEfficiency : EfficiencyValue = 32 [%];
        attribute sealIntegrity : Boolean = true;
        attribute cycleFrequency : Real = 25;

        part expansionChamber : ExpansionChamber {
            wallTemperature = 923 [K];
        }

        part compressionChamber : CompressionChamber {
            wallTemperature = 293 [K];
        }

        part displacerPiston : DisplacerPiston {
            position = 0 [m];
        }

        part powerPiston : PowerPiston {
            position = 0 [m];
        }

        part regenerator : Regenerator;

        part crankshaft : Crankshaft {
            currentAngle = 0 [rad];
            outputTorque = 5 [N.m];
        }

        part flywheel : Flywheel {
            angularVelocity = 100 [rad/s];
        }

        connect heatInput to expansionChamber.heatIn;
        connect expansionChamber.gasOut to regenerator.gasFromHot;
        connect regenerator.gasToCold to compressionChamber.gasIn;
        connect compressionChamber.gasExit to regenerator.gasFromCold;
        connect regenerator.gasToHot to expansionChamber.gasReturn;
        connect compressionChamber.heatOut to heatRejection;
        connect displacerPiston.gasDisplacement to expansionChamber.gasReturn;
        connect expansionChamber.gasOut to powerPiston.gasPressure;
        connect powerPiston.linearForce to crankshaft.linearInput;
        connect crankshaft.rotationalOutput to flywheel.rotationalInput;
        connect flywheel.rotationalOutput to mechanicalOutput;

        state def ThermodynamicCycle {
            entry; then isothermalExpansion;

            state isothermalExpansion {
                entry {
                    workingGas.temperature = heatSourceTemperature;
                }
                do {
                    powerPiston.position = powerPiston.position + powerPiston.stroke;
                }
            }

            transition isothermalExpansion to constantVolumeCooling
                when powerPiston.position >= powerPiston.stroke;

            state constantVolumeCooling {
                entry {
                    workingGas.temperature = heatSinkTemperature;
                }
                do {
                    displacerPiston.position = displacerPiston.position + displacerPiston.stroke;
                }
            }

            transition constantVolumeCooling to isothermalCompression
                when displacerPiston.position >= displacerPiston.stroke;

            state isothermalCompression {
                entry {
                    workingGas.pressure = workingGas.pressure * 0.5;
                }
                do {
                    powerPiston.position = powerPiston.position - powerPiston.stroke;
                }
            }

            transition isothermalCompression to constantVolumeHeating
                when powerPiston.position <= 0 [m];

            state constantVolumeHeating {
                entry {
                    workingGas.temperature = heatSourceTemperature;
                }
                do {
                    displacerPiston.position = displacerPiston.position - displacerPiston.stroke;
                }
            }

            transition constantVolumeHeating to isothermalExpansion
                when displacerPiston.position <= 0 [m];
        }

        action def ExecuteCycle {
            in gas : WorkingGas;
            out mechanicalWork : EnergyValue;

            action expandGas {
                in gasIn : WorkingGas;
                out gasOut : WorkingGas;
                out workOut : EnergyValue;
            }

            action transferToCold {
                in gasIn : WorkingGas;
                out gasOut : WorkingGas;
            }

            action compressGas {
                in gasIn : WorkingGas;
                out gasOut : WorkingGas;
                out workIn : EnergyValue;
            }

            action transferToHot {
                in gasIn : WorkingGas;
                out gasOut : WorkingGas;
            }

            then expandGas;
            expandGas then transferToCold;
            transferToCold then compressGas;
            compressGas then transferToHot;
            transferToHot then expandGas;
        }

        action def RegenerateHeat {
            in hotGas : WorkingGas;
            in coldGas : WorkingGas;
            out cooledGas : WorkingGas;
            out heatedGas : WorkingGas;

            action absorbHeat : Regenerator.AbsorbHeat;
            action releaseHeat : Regenerator.ReleaseHeat;

            then absorbHeat;
            then releaseHeat;
        }
    }

    part StirlingEngineAssembly {
        part heatSource : HeatSource {
            outputTemperature = 923 [K];
            heatRate = 2000 [W];
            fuelType = "SolarConcentrated";
        }

        part heatSink : HeatSink {
            sinkTemperature = 293 [K];
            coolingCapacity = 1500 [W];
            coolingMedium = "AmbientAir";
        }

        part engine : StirlingEngine {
            heatSourceTemperature = 923 [K];
            heatSinkTemperature = 293 [K];
            outputPower = 500 [W];
            outputStability = 92 [%];
            thermalEfficiency = 32 [%];
        }

        connect heatSource.thermalOutput to engine.heatInput;
        connect engine.heatRejection to heatSink.thermalInput;

        satisfy ContinuousPowerRequirement by engine;
        satisfy TemperatureDifferentialRequirement by engine;
        satisfy EfficiencyRequirement by engine;
        satisfy SealedGasRequirement by engine;
        satisfy FlywheelStabilityRequirement by engine.flywheel;
    }
}
