// Design a system based on a Air ioniser and describe its primary function at a high level.
package AirIoniserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def IonConcentration :> Real;
    attribute def ParticleCount :> Real;
    attribute def OzoneLevel :> Real;

    enum def OperatingMode {
        off;
        standby;
        low;
        medium;
        high;
        auto;
    }

    enum def IonPolarity {
        negative;
        positive;
        bipolar;
    }

    item def AirSample {
        attribute ionDensity : IonConcentration;
        attribute particleCount : ParticleCount;
        attribute ozonePpm : OzoneLevel;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
    }

    port def AirPort {
        attribute sample : AirSample;
    }

    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def ControlPort {
        attribute command : OperatingMode;
        attribute feedback : Real;
    }

    part def PowerSupply {
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        port acIn : PowerPort;
        port dcOut : PowerPort;
    }

    part def HighVoltageGenerator {
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
        port powerIn : PowerPort;
        port hvOut : PowerPort;
    }

    part def IonEmitter {
        attribute polarity : IonPolarity;
        attribute emissionRate : IonConcentration;
        attribute needleCount : Integer;
        port hvIn : PowerPort;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def Fan {
        attribute speed : Real;
        attribute maxFlowRate : VolumeFlowRateValue;
        attribute commandedFlowRate : VolumeFlowRateValue;
        port powerIn : PowerPort;
        port airIn : AirPort;
        port airOut : AirPort;
    }

    part def AirQualitySensor {
        attribute particleReading : ParticleCount;
        attribute ionReading : IonConcentration;
        attribute ozoneReading : OzoneLevel;
        port sensorPort : AirPort;
        port dataOut : ControlPort;
    }

    part def Controller {
        attribute currentMode : OperatingMode;
        attribute targetIonDensity : IonConcentration;
        attribute ionTolerance : IonConcentration;
        attribute maxOzonePpm : OzoneLevel;
        attribute minFlowRate : VolumeFlowRateValue;
        attribute maxFlowRate : VolumeFlowRateValue;
        port sensorIn : ControlPort;
        port fanControl : ControlPort;
        port emitterControl : ControlPort;
        port userInterface : ControlPort;
    }

    action def MonitorAirQuality {
        in airSample : AirSample;
        out ionDensity : IonConcentration;
        out particleCount : ParticleCount;
        out ozonePpm : OzoneLevel;
    }

    action def GenerateIons {
        in voltage : ElectricPotentialValue;
        in polarity : IonPolarity;
        in airflowRate : VolumeFlowRateValue;
        out ionConcentration : IonConcentration;
        out ozoneGenerated : OzoneLevel;
    }

    action def CirculateAir {
        in fanSpeed : Real;
        in airIn : AirSample;
        out airOut : AirSample;
        out flowRate : VolumeFlowRateValue;
    }

    action def AdjustOperation {
        in measuredIon : IonConcentration;
        in targetIon : IonConcentration;
        in tolerance : IonConcentration;
        in ozone : OzoneLevel;
        in maxOzone : OzoneLevel;
        in mode : OperatingMode;
        out newVoltage : ElectricPotentialValue;
        out newFanSpeed : Real;
    }

    action def PurifyAir {
        first start;
        then merge monitoringLoop;
        
        action monitor : MonitorAirQuality {
            in airSample : AirSample;
            out currentIonDensity : IonConcentration;
            out currentParticles : ParticleCount;
            out currentOzone : OzoneLevel;
        }
        then monitoringLoop;
        
        then decide;
            if monitor.currentOzone > 0.05 then reduceOperation;
            if monitor.currentIonDensity < 8.0E9 then increaseIonisation;
            if monitor.currentIonDensity >= 8.0E9 then maintainIonisation;
        
        action reduceOperation {
            action lowerVoltage : AdjustOperation {
                in measuredIon = monitor.currentIonDensity;
                in ozone = monitor.currentOzone;
                out safeVoltage : ElectricPotentialValue;
                out safeSpeed : Real;
            }
            action circulateMax : CirculateAir {
                in fanSpeed = lowerVoltage.safeSpeed;
            }
        }
        then monitoringLoop;
        
        action increaseIonisation {
            action raiseVoltage : AdjustOperation {
                in measuredIon = monitor.currentIonDensity;
                in ozone = monitor.currentOzone;
                out highVoltage : ElectricPotentialValue;
                out highSpeed : Real;
            }
            action generateHighIons : GenerateIons {
                in voltage = raiseVoltage.highVoltage;
                in polarity = IonPolarity::negative;
            }
            action circulateHigh : CirculateAir {
                in fanSpeed = raiseVoltage.highSpeed;
            }
        }
        then monitoringLoop;
        
        action maintainIonisation {
            action steadyVoltage : AdjustOperation {
                in measuredIon = monitor.currentIonDensity;
                in ozone = monitor.currentOzone;
                out steadyV : ElectricPotentialValue;
                out steadySpeed : Real;
            }
            action generateSteadyIons : GenerateIons {
                in voltage = steadyVoltage.steadyV;
                in polarity = IonPolarity::negative;
            }
            action circulateSteady : CirculateAir {
                in fanSpeed = steadyVoltage.steadySpeed;
            }
        }
        then monitoringLoop;
    }

    state def IoniserStates {
        entry; then off;
        
        state off;
        transition off_to_standby
            first off
            accept OperatingMode::standby
            then standby;
        
        state standby;
        transition standby_to_active
            first standby
            accept OperatingMode::low
            then active;
        
        state active {
            entry; then lowPower;
            
            state lowPower;
            state mediumPower;
            state highPower;
            
            transition low_to_medium
                first lowPower
                accept OperatingMode::medium
                then mediumPower;
            
            transition medium_to_high
                first mediumPower
                accept OperatingMode::high
                then highPower;
            
            transition high_to_medium
                first highPower
                accept OperatingMode::medium
                then mediumPower;
            
            transition medium_to_low
                first mediumPower
                accept OperatingMode::low
                then lowPower;
        }
        
        transition active_to_standby
            first active
            accept OperatingMode::standby
            then standby;
        
        transition standby_to_off
            first standby
            accept OperatingMode::off
            then off;
    }

    part def AirIoniser {
        attribute operatingMode : OperatingMode;
        attribute totalPower : PowerValue;
        attribute ionOutput : IonConcentration;
        attribute coverageArea : AreaValue;
        
        port airInlet : AirPort;
        port airOutlet : AirPort;
        port mainPower : PowerPort;
        
        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 120 [V];
            attribute :>> outputVoltage = 12 [V];
            attribute :>> maxCurrent = 2.5 [A];
        }
        
        part hvGenerator : HighVoltageGenerator {
            attribute :>> inputVoltage = 12 [V];
            attribute :>> outputVoltage = 6000 [V];
            attribute :>> frequency = 50000 [Hz];
        }
        
        part emitter : IonEmitter {
            attribute :>> polarity = IonPolarity::negative;
            attribute :>> emissionRate = 10000000;
            attribute :>> needleCount = 6;
        }
        
        part fan : Fan {
            attribute :>> speed = 70;
            attribute :>> maxFlowRate = 200 [m^3/h];
            attribute :>> commandedFlowRate = 120 [m^3/h];
        }
        
        part sensor : AirQualitySensor {
            attribute :>> particleReading = 0;
            attribute :>> ionReading = 0;
            attribute :>> ozoneReading = 0;
        }
        
        part controller : Controller {
            attribute :>> currentMode = OperatingMode::standby;
            attribute :>> targetIonDensity = 10000000;
            attribute :>> ionTolerance = 1000000;
            attribute :>> maxOzonePpm = 0.05;
            attribute :>> minFlowRate = 80 [m^3/h];
            attribute :>> maxFlowRate = 200 [m^3/h];
        }
        
        connection powerToDC connect mainPower to powerSupply.acIn;
        connection dcToHV connect powerSupply.dcOut to hvGenerator.powerIn;
        connection hvToEmitter connect hvGenerator.hvOut to emitter.hvIn;
        connection dcToFan connect powerSupply.dcOut to fan.powerIn;
        
        connection airIntake connect airInlet to fan.airIn;
        connection fanToEmitter connect fan.airOut to emitter.airIn;
        connection emitterToSensor connect emitter.airOut to sensor.sensorPort;
        connection sensorToOutlet connect sensor.sensorPort to airOutlet;
        
        connection sensorToController connect sensor.dataOut to controller.sensorIn;
        connection controllerToFan connect controller.fanControl to fan.powerIn;
        connection controllerToEmitter connect controller.emitterControl to emitter.hvIn;
        
        perform action purifyAir : PurifyAir;
    }

    requirement <'REQ-AI-001'> primaryFunction {
        doc /* The air ioniser system shall purify indoor air by generating 
             * negative ions that attach to airborne particles, causing them 
             * to become electrically charged and precipitate out of the air, 
             * thereby reducing allergens, dust, smoke, bacteria, and other 
             * pollutants to improve overall air quality and create a healthier 
             * breathing environment.
             */
        subject ioniser : AirIoniser;
    }

    requirement <'REQ-AI-002'> ionGeneration {
        doc /* The system shall generate negative ions at a minimum concentration 
             * of 10 million ions per cubic centimeter to effectively neutralize 
             * airborne contaminants.
             */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.ionOutput >= 10000000
        }
    }

    requirement <'REQ-AI-003'> coverageArea {
        doc /* The air ioniser shall provide effective coverage for an area of 
             * at least 40 square meters.
             */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.coverageArea >= 40 [m^2]
        }
    }

    requirement <'REQ-AI-004'> ozoneSafety {
        doc /* The system shall maintain ozone generation below 0.05 ppm to 
             * comply with safety standards and prevent health hazards.
             */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.sensor.ozoneReading <= 0.05
        }
    }

    requirement <'REQ-AI-005'> powerEfficiency {
        doc /* The air ioniser shall consume no more than 30 watts during 
             * normal operation to ensure energy efficiency.
             */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.totalPower <= 30 [W]
        }
    }

    requirement <'REQ-AI-006'> airflowRate {
        doc /* The system shall maintain a minimum airflow rate of 100 cubic 
             * meters per hour to ensure adequate air circulation.
             */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.fan.commandedFlowRate >= 100 [m^3/h]
        }
    }

    part airIoniserSystem : AirIoniser {
        attribute :>> operatingMode = OperatingMode::auto;
        attribute :>> totalPower = 25 [W];
        attribute :>> ionOutput = 12000000;
        attribute :>> coverageArea = 45 [m^2];
    }

    satisfy primaryFunction by airIoniserSystem;
    satisfy ionGeneration by airIoniserSystem;
    satisfy coverageArea by airIoniserSystem;
    satisfy ozoneSafety by airIoniserSystem;
    satisfy powerEfficiency by airIoniserSystem;
    satisfy airflowRate by airIoniserSystem;
}
