package AirIoniserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def IonConcentration :> Real;
    attribute def ParticleCount :> Real;

    item def ContaminatedAir {
        attribute particleCount : ParticleCount;
        attribute odorLevel : Real;
    }

    item def IonizedAir :> ContaminatedAir {
        attribute ionConcentration : IonConcentration;
    }

    item def CleanAir :> IonizedAir {
        attribute particleReduction : Real;
    }

    part def IonGenerator {
        attribute ionProductionRate : IonConcentration;
        attribute operatingVoltage : Real;
        attribute powerConsumption : PowerValue;
    }

    part def AirCirculationFan {
        attribute airFlowRate : VolumeFlowRateValue;
        attribute powerConsumption : PowerValue;
    }

    part def ParticleCollector {
        attribute collectionEfficiency : Real;
        attribute mass : MassValue;
    }

    part def AirQualitySensor {
        attribute particleLevel : ParticleCount;
        attribute ionLevel : IonConcentration;
    }

    part def ControlModule {
        attribute operatingMode : OperatingMode;
    }

    part def PowerSupply {
        attribute outputPower : PowerValue;
        attribute inputVoltage : Real;
    }

    enum def OperatingMode {
        off;
        standby;
        purifying;
        boost;
    }

    action def DrawContaminatedAir {
        out air : ContaminatedAir;
    }

    action def GenerateIons {
        out ionCount : IonConcentration;
    }

    action def ChargeParticles {
        in air : ContaminatedAir;
        in ions : IonConcentration;
        out ionizedAir : IonizedAir;
    }

    action def CollectParticles {
        in air : IonizedAir;
        out cleanAir : CleanAir;
    }

    action def MonitorAirQuality {
        out particleLevel : ParticleCount;
        out ionLevel : IonConcentration;
    }

    action def ContinuePurification;
    action def StopPurification;

    action def PurifyAir {
        first start;
        then merge continueCycle;
        then action draw : DrawContaminatedAir {
            out airIn : ContaminatedAir;
        }
        then action generate : GenerateIons {
            out ions : IonConcentration;
        }
        then action charge : ChargeParticles {
            in air = draw.airIn;
            in ions = generate.ions;
            out charged : IonizedAir;
        }
        then action collect : CollectParticles {
            in air = charge.charged;
            out purified : CleanAir;
        }
        then action monitor : MonitorAirQuality {
            out particles : ParticleCount;
            out ions : IonConcentration;
        }
        then decide;
            if monitor.particles > 30 then continueAction;
            if monitor.particles <= 30 then stopAction;
        action continueAction : ContinuePurification;
        then continueCycle;
        action stopAction : StopPurification;
        then done;
    }

    state def IoniserOperatingStates {
        entry; then idle;
        
        state idle;
        transition first idle
            then active;
        
        state active {
            entry; then purifying;
            
            state purifying;
            state monitoring;
            
            transition first purifying
                then monitoring;
            transition first monitoring
                then purifying;
        }
        
        transition first active
            then idle;
    }

    part def AirIoniser {
        attribute totalPowerConsumption : PowerValue;
        attribute effectiveCoverageArea : AreaValue;
        attribute totalMass : MassValue;
        attribute maxIonOutput : IonConcentration;
        
        part ionGenerator : IonGenerator {
            attribute :>> ionProductionRate;
            attribute :>> operatingVoltage = 5000;
            attribute :>> powerConsumption;
        }
        
        part fan : AirCirculationFan {
            attribute :>> airFlowRate;
            attribute :>> powerConsumption;
        }
        
        part collector : ParticleCollector {
            attribute :>> collectionEfficiency;
            attribute :>> mass;
        }
        
        part sensor : AirQualitySensor {
            attribute :>> particleLevel;
            attribute :>> ionLevel;
        }
        
        part controller : ControlModule {
            attribute :>> operatingMode;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> outputPower;
            attribute :>> inputVoltage = 120;
        }
        
        perform action purificationCycle : PurifyAir[*];
        
        state operationState : IoniserOperatingStates;
        
        assert constraint totalPowerConstraint {
            totalPowerConsumption == ionGenerator.powerConsumption + fan.powerConsumption
        }
        
        assert constraint massConstraint {
            totalMass == ionGenerator.powerConsumption.num * 0.1[kg] + 
                         fan.powerConsumption.num * 0.15[kg] + 
                         collector.mass + 
                         0.5[kg]
        }
    }

    part residentialIoniser : AirIoniser {
        attribute :>> totalPowerConsumption = 38[W];
        attribute :>> effectiveCoverageArea = 40[m^2];
        attribute :>> totalMass = 2.8[kg];
        attribute :>> maxIonOutput = 2500000;
        
        part :>> ionGenerator {
            attribute :>> ionProductionRate = 2500000;
            attribute :>> powerConsumption = 22[W];
        }
        
        part :>> fan {
            attribute :>> airFlowRate = 155[m^3/h];
            attribute :>> powerConsumption = 16[W];
        }
        
        part :>> collector {
            attribute :>> collectionEfficiency = 0.91;
            attribute :>> mass = 0.4[kg];
        }
        
        part :>> sensor {
            attribute :>> particleLevel = 22;
            attribute :>> ionLevel = 2500000;
        }
        
        part :>> controller {
            attribute :>> operatingMode = OperatingMode::purifying;
        }
        
        part :>> powerSupply {
            attribute :>> outputPower = 38[W];
        }
    }

    requirement <'AIR-REQ-001'> primaryPurificationFunction {
        doc /* The air ioniser shall purify indoor air by generating 
             * negative ions that attach to airborne particles, allergens, 
             * and contaminants, causing them to become charged and be 
             * collected, thereby improving air quality.
            */
        subject ioniser : AirIoniser;
    }

    requirement <'AIR-REQ-002'> ionGenerationCapacity {
        doc /* The ion generator shall produce at least 2,000,000 negative 
             * ions per cubic centimeter to ensure effective particle charging 
             * and air purification.
            */
        subject generator :>> residentialIoniser.ionGenerator;
        assert constraint {
            generator.ionProductionRate >= 2000000
        }
    }

    requirement <'AIR-REQ-003'> powerEfficiency {
        doc /* The total power consumption shall not exceed 45 watts during 
             * continuous operation to maintain energy efficiency.
            */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.totalPowerConsumption <= 45[W]
        }
    }

    requirement <'AIR-REQ-004'> coverageArea {
        doc /* The air ioniser shall effectively purify air in an area of 
             * at least 35 square meters.
            */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.effectiveCoverageArea >= 35[m^2]
        }
    }

    requirement <'AIR-REQ-005'> airCirculation {
        doc /* The circulation fan shall move air at a minimum rate of 
             * 140 cubic meters per hour to ensure adequate air exchange 
             * and ion distribution.
            */
        subject fan :>> residentialIoniser.fan;
        assert constraint {
            fan.airFlowRate >= 140[m^3/h]
        }
    }

    requirement <'AIR-REQ-006'> particleCollection {
        doc /* The particle collector shall capture at least 88% of 
             * charged particles from the air stream.
            */
        subject collector :>> residentialIoniser.collector;
        assert constraint {
            collector.collectionEfficiency >= 0.88
        }
    }

    requirement <'AIR-REQ-007'> portabilityMass {
        doc /* The total mass shall not exceed 3.2 kilograms to ensure 
             * portability and ease of placement.
            */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.totalMass <= 3.2[kg]
        }
    }

    satisfy primaryPurificationFunction by residentialIoniser;
    satisfy ionGenerationCapacity by residentialIoniser.ionGenerator;
    satisfy powerEfficiency by residentialIoniser;
    satisfy coverageArea by residentialIoniser;
    satisfy airCirculation by residentialIoniser.fan;
    satisfy particleCollection by residentialIoniser.collector;
    satisfy portabilityMass by residentialIoniser;
}
