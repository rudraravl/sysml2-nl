package EnergyAbsorptionSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {

    attribute def FaultSignal;
    attribute def 'Excessive Deformation Fault' :> FaultSignal;
    attribute def 'Over Temperature Fault' :> FaultSignal;
    attribute def 'Impact Event';
    attribute def 'Reset';

    item def ImpactForce {
        attribute magnitude :> ISQ::force;
    }
    item def DeformationData {
        attribute permanentDeformation :> ISQ::length;
    }
    item def TemperatureData {
        attribute temperature :> ISQ::temperature;
    }
    item def ThermalLoad {
        attribute heatFlux :> ISQ::power;
    }
    item def SensorData {
        attribute measuredForce :> ISQ::force;
        attribute permanentDeformation :> ISQ::length;
        attribute temperature :> ISQ::temperature;
    }

    port def ImpactPort {
        in item impactForce : ImpactForce;
        out item residualForce : ImpactForce;
    }
    port def ThermalPort {
        in item heatFlow : ThermalLoad;
        out item dissipatedHeat : ThermalLoad;
    }
    port def ForceSensorPort {
        in item impactForce : ImpactForce;
    }
    port def DeformationOutPort {
        out item deformationData : DeformationData;
    }
    port def DeformationSensorPort {
        in item deformationData : DeformationData;
    }
    port def TemperatureOutPort {
        out item temperatureData : TemperatureData;
    }
    port def TemperatureSensorPort {
        in item temperatureData : TemperatureData;
    }
    port def SensorDataPort {
        out item sensorData : SensorData;
    }
    port def MountingPort {
        attribute attachmentForce :> ISQ::force;
        attribute attachmentPointId : Integer;
    }

    action def DistributeLoad {
        in item impact : ImpactForce;
        out item distributed : ImpactForce;
    }
    action def AbsorbImpact {
        in item impact : ImpactForce;
        out item residual : ImpactForce;
        attribute absorbedEnergy :> ISQ::energy;
    }
    action def DissipateHeat {
        in item heat : ThermalLoad;
        out item radiatedHeat : ThermalLoad;
    }
    action def TransferResidualForce {
        in item residual : ImpactForce;
        out item transferred : ImpactForce;
    }
    action def MonitorSensors {
        out item data : SensorData;
    }

    state def FoamCrushStates;
    state def SystemStates;

    part def ProtectiveEnclosure {
        attribute material : String = "Steel";
        attribute thickness :> ISQ::length = 5.0 [mm];
        attribute yieldStrength :> ISQ::pressure = 250.0 [MPa];
        port externalImpactPort : ImpactPort;
        port innerFacePort : ImpactPort;
        port thermalPort : ThermalPort;
        perform action distributeLoad : DistributeLoad;
    }

    part def MetalFoamCore {
        attribute material : String = "AluminumAlloyFoam";
        attribute density :> ISQ::massDensity = 0.45 [g/cm^3];
        attribute porosity : Real = 0.83;
        attribute thermalConductivity :> ISQ::thermalConductivity = 150.0 [W/(m*K)];
        attribute elasticDeformationLimit :> ISQ::length = 5.0 [mm];
        attribute plateauDeformationLimit :> ISQ::length = 35.0 [mm];
        attribute densificationStrain : Real = 0.7;
        attribute maxDeformation :> ISQ::length = 50.0 [mm];
        attribute maxTemperature :> ISQ::temperature = 423.15 [K];
        attribute currentDeformation :> ISQ::length = 0.0 [mm];
        attribute currentTemperature :> ISQ::temperature = 298.15 [K];
        attribute currentForce :> ISQ::force = 0.0 [N];
        attribute plateauForce :> ISQ::force = 8000.0 [N];
        port loadPort : ImpactPort;
        port residualForcePort : ImpactPort;
        port thermalPort : ThermalPort;
        port deformationOut : DeformationOutPort;
        port temperatureOut : TemperatureOutPort;
        perform action absorbImpact : AbsorbImpact;
        perform action dissipateHeat : DissipateHeat;
        exhibit state foamCrushStates : FoamCrushStates;
    }

    part def MountingBracket {
        attribute material : String = "Steel";
        attribute attachmentPointCount : Integer = 4;
        port mountingPorts : MountingPort[4];
        port residualForcePort : ImpactPort;
        perform action transferResidualForce : TransferResidualForce;
    }

    part def SensorArray {
        attribute samplingRate :> ISQ::frequency = 100.0 [Hz];
        attribute forceRange :> ISQ::force = 50000.0 [N];
        attribute deformationRange :> ISQ::length = 100.0 [mm];
        attribute temperatureRange :> ISQ::temperature = 473.15 [K];
        port forceSensorPort : ForceSensorPort;
        port deformationSensorPort : DeformationSensorPort;
        port temperatureSensorPort : TemperatureSensorPort;
        port dataOutPort : SensorDataPort;
        perform action monitorSensors : MonitorSensors;
    }

    part def EnergyAbsorptionUnit {
        attribute totalMass :> ISQ::mass = 2.5 [kg];
        attribute maxAbsorbedEnergy :> ISQ::energy = 500.0 [J];
        part enclosure : ProtectiveEnclosure;
        part foamCore : MetalFoamCore;
        part bracket : MountingBracket;
        part sensors : SensorArray;
        port externalImpactPort : ImpactPort;
        port externalThermalPort : ThermalPort;
        port externalDataPort : SensorDataPort;
        port externalMountingPorts : MountingPort[4];

        connect externalImpactPort to enclosure.externalImpactPort;
        connect enclosure.innerFacePort to foamCore.loadPort;
        connect foamCore.residualForcePort to bracket.residualForcePort;
        connect bracket.mountingPorts to externalMountingPorts;
        connect externalThermalPort to enclosure.thermalPort;
        connect enclosure.thermalPort to foamCore.thermalPort;
        connect foamCore.loadPort to sensors.forceSensorPort;
        connect foamCore.deformationOut to sensors.deformationSensorPort;
        connect foamCore.temperatureOut to sensors.temperatureSensorPort;
        connect sensors.dataOutPort to externalDataPort;

        exhibit state systemStates : SystemStates;
    }

    requirement def EnergyAbsorptionRequirement {
        attribute minAbsorbedEnergy :> ISQ::energy;
        attribute maxPeakForce :> ISQ::force;
        subject unit : EnergyAbsorptionUnit;
        assert constraint {
            unit.maxAbsorbedEnergy >= minAbsorbedEnergy and
            unit.foamCore.plateauForce <= maxPeakForce
        }
    }

    requirement def ThermalManagementRequirement {
        attribute minThermalConductivity :> ISQ::thermalConductivity;
        subject unit : EnergyAbsorptionUnit;
        assert constraint {
            unit.foamCore.thermalConductivity >= minThermalConductivity
        }
    }

    requirement def StructuralIntegrityRequirement {
        attribute maxDeformationLimit :> ISQ::length;
        attribute maxTemperatureLimit :> ISQ::temperature;
        subject unit : EnergyAbsorptionUnit;
        assert constraint {
            unit.foamCore.currentDeformation <= maxDeformationLimit and
            unit.foamCore.currentTemperature <= maxTemperatureLimit
        }
    }

    requirement def MountingRequirement {
        attribute minAttachmentPoints : Integer = 4;
        subject unit : EnergyAbsorptionUnit;
        assert constraint {
            unit.bracket.attachmentPointCount >= minAttachmentPoints
        }
    }
    }

    package Usages {
        private import Definitions::*;

        part energyAbsorptionUnit : EnergyAbsorptionUnit;

        action 'distribute load' : DistributeLoad;
        action 'absorb impact' : AbsorbImpact;
        action 'dissipate heat' : DissipateHeat;
        action 'transfer residual force' : TransferResidualForce;
        action 'monitor sensors' : MonitorSensors;

        state 'foam crush states' : FoamCrushStates {
            entry; then elastic;
            state elastic {
                do 'absorb impact';
            }
            accept when energyAbsorptionUnit.foamCore.currentDeformation > energyAbsorptionUnit.foamCore.elasticDeformationLimit
                then plateau;
            state plateau {
                do 'absorb impact';
            }
            accept when energyAbsorptionUnit.foamCore.currentDeformation > energyAbsorptionUnit.foamCore.plateauDeformationLimit
                then densification;
            state densification {
                do 'absorb impact';
            }
            accept 'Reset'
                then elastic;
        }

        state 'system states' : SystemStates parallel {
            state 'operational states' {
                entry; then idle;
                state idle {
                    do 'monitor sensors';
                }
                accept 'Impact Event'
                    then active;
                state active {
                    do 'distribute load';
                    do 'absorb impact';
                    do 'transfer residual force';
                    do 'monitor sensors';
                }
                accept when energyAbsorptionUnit.foamCore.currentDeformation >= energyAbsorptionUnit.foamCore.maxDeformation
                    then compromised;
                state compromised {
                    do 'monitor sensors';
                }
                accept 'Reset'
                    then idle;
            }

            state 'health states' {
                entry; then normal;
                state normal {
                    do 'monitor sensors';
                }
                accept when energyAbsorptionUnit.foamCore.currentDeformation > energyAbsorptionUnit.foamCore.maxDeformation
                    do send new 'Excessive Deformation Fault'() to energyAbsorptionUnit.sensors
                    then fault;
                accept when energyAbsorptionUnit.foamCore.currentTemperature > energyAbsorptionUnit.foamCore.maxTemperature
                    do send new 'Over Temperature Fault'() to energyAbsorptionUnit.sensors
                    then fault;
                state fault {
                    do 'monitor sensors';
                }
                accept 'Reset'
                    then normal;
            }

            state 'thermal management' {
                entry; then conducting;
                state conducting {
                    do 'dissipate heat';
                }
            }
        }

        requirement 'Energy Absorption Requirement' : EnergyAbsorptionRequirement {
            attribute minAbsorbedEnergy = 500.0 [J];
            attribute maxPeakForce = 15000.0 [N];
            subject unit :> energyAbsorptionUnit;
        }

        requirement 'Thermal Management Requirement' : ThermalManagementRequirement {
            attribute minThermalConductivity = 100.0 [W/(m*K)];
            subject unit :> energyAbsorptionUnit;
        }

        requirement 'Structural Integrity Requirement' : StructuralIntegrityRequirement {
            attribute maxDeformationLimit = 50.0 [mm];
            attribute maxTemperatureLimit = 423.15 [K];
            subject unit :> energyAbsorptionUnit;
        }

        requirement 'Mounting Requirement' : MountingRequirement {
            attribute minAttachmentPoints = 4;
            subject unit :> energyAbsorptionUnit;
        }
    }
}
