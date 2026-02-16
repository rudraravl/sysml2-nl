package PhototransistorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def IlluminanceLevel :> ISQ::IlluminanceValue;
    attribute def PhotocurrentLevel :> ISQ::ElectricCurrentValue;
    attribute def VoltageLevel :> ISQ::ElectricPotentialValue;
    attribute def ResistanceValue :> ISQ::ResistanceValue;
    attribute def Responsivity;

    port def OpticalPort {
        in attribute incidentLight : IlluminanceLevel;
    }

    port def ElectricalPort {
        out attribute outputCurrent : PhotocurrentLevel;
        out attribute outputVoltage : VoltageLevel;
    }

    port def PowerPort {
        in attribute supplyVoltage : VoltageLevel;
    }

    item def LightSignal {
        attribute intensity : IlluminanceLevel;
        attribute wavelength : ISQ::LengthValue;
    }

    part def Phototransistor {
        doc /* 
            A three-terminal semiconductor device that converts optical 
            radiation into electrical current through photoelectric effect 
            in the base-collector junction.
        */

        attribute responsivity : Responsivity;
        attribute currentGain : Real;
        attribute darkCurrent : PhotocurrentLevel;

        port opticalInput : OpticalPort;
        port electricalOutput : ElectricalPort;
        port power : PowerPort;

        action def GeneratePhotocurrent {
            in lightIntensity : IlluminanceLevel;
            in responsivity : Responsivity;
            out baseCurrent : PhotocurrentLevel;
        }

        action def AmplifyBaseCurrent {
            in baseCurrent : PhotocurrentLevel;
            in gain : Real;
            out collectorCurrent : PhotocurrentLevel;
        }

        state def OperatingMode {
            entry; then cutoffMode;

            state cutoffMode {
                doc /* No light detected, minimal dark current flows */
            }

            transition cutoffToActive
                first cutoffMode
                accept when opticalInput.incidentLight > 1.0
                then activeMode;

            state activeMode {
                doc /* Light detected, photocurrent generated and amplified */
                entry; then linearRegion;

                state linearRegion {
                    doc /* Output current proportional to light intensity */
                }

                transition linearToSaturation
                    first linearRegion
                    accept when opticalInput.incidentLight > 10000.0
                    then saturationRegion;

                state saturationRegion {
                    doc /* Maximum collector current reached */
                }

                transition saturationToLinear
                    first saturationRegion
                    accept when opticalInput.incidentLight <= 10000.0
                    then linearRegion;
            }

            transition activeToCutoff
                first activeMode
                accept when opticalInput.incidentLight <= 1.0
                then cutoffMode;
        }
    }

    part def CollectorResistor {
        attribute resistance : ResistanceValue;
        port input : ElectricalPort;
        port output : ElectricalPort;

        constraint voltageDropCalculation {
            output.outputVoltage == input.outputCurrent * resistance
        }
    }

    part def VoltageSupply {
        attribute nominalVoltage : VoltageLevel;
        port powerOutput : PowerPort;
    }

    part def SignalConditioner {
        port electricalInput : ElectricalPort;
        
        action def FilterSignal {
            in rawVoltage : VoltageLevel;
            out filteredVoltage : VoltageLevel;
        }

        action def ConvertToDigital {
            in analogVoltage : VoltageLevel;
            out digitalValue : Boolean;
            out analogLevel : Real;
        }
    }

    action def ConvertOpticalToElectrical {
        in lightInput : IlluminanceLevel;
        in deviceResponsivity : Responsivity;
        in deviceGain : Real;
        in supplyVoltage : VoltageLevel;
        in loadResistance : ResistanceValue;
        out photocurrent : PhotocurrentLevel;
        out outputVoltage : VoltageLevel;

        action generateBase : Phototransistor::GeneratePhotocurrent {
            in lightIntensity = lightInput;
            in responsivity = deviceResponsivity;
            out baseCurrent;
        }

        then action amplify : Phototransistor::AmplifyBaseCurrent {
            in baseCurrent = generateBase.baseCurrent;
            in gain = deviceGain;
            out collectorCurrent;
        }

        then assign photocurrent := amplify.collectorCurrent;
        then assign outputVoltage := supplyVoltage - (photocurrent * loadResistance);
    }

    action def MonitorAndProcess {
        in ambientLight : IlluminanceLevel;
        in responsivity : Responsivity;
        in gain : Real;
        in vcc : VoltageLevel;
        in rLoad : ResistanceValue;
        out processedSignal : Boolean;
        out signalLevel : Real;

        loop {
            action convert : ConvertOpticalToElectrical {
                in lightInput = ambientLight;
                in deviceResponsivity = responsivity;
                in deviceGain = gain;
                in supplyVoltage = vcc;
                in loadResistance = rLoad;
                out photocurrent;
                out outputVoltage;
            }

            then action condition : SignalConditioner::ConvertToDigital {
                in analogVoltage = convert.outputVoltage;
                out digitalValue;
                out analogLevel;
            }

            then assign processedSignal := condition.digitalValue;
            then assign signalLevel := condition.analogLevel;
        }
    }

    part def OpticalDetectionSystem {
        doc /*
            The phototransistor-based optical detection system's primary 
            function is to sense ambient light levels and convert them into 
            usable electrical signals for monitoring and control applications.
            
            When light photons strike the base-collector junction of the 
            phototransistor, they generate electron-hole pairs that produce 
            a small photocurrent. This photocurrent acts as the base current 
            and is amplified by the transistor's current gain, resulting in 
            a much larger collector current. This amplified current flows 
            through a load resistor, creating a voltage signal that varies 
            proportionally with the incident light intensity.
            
            The system continuously monitors light levels and produces 
            corresponding electrical outputs suitable for applications such 
            as automatic lighting control, optical switches, proximity 
            detection, and light-based communication receivers.
        */

        attribute systemResponsivity : Responsivity := 0.5;
        attribute systemGain : Real := 100.0;
        attribute loadResistance : ResistanceValue := 10000.0;
        attribute supplyVoltage : VoltageLevel := 5.0;

        part sensor : Phototransistor {
            attribute :>> responsivity = systemResponsivity;
            attribute :>> currentGain = systemGain;
            attribute :>> darkCurrent = 0.000001;
        }

        part loadR : CollectorResistor {
            attribute :>> resistance = loadResistance;
        }

        part powerSupply : VoltageSupply {
            attribute :>> nominalVoltage = supplyVoltage;
        }

        part conditioner : SignalConditioner;

        port opticalInterface : OpticalPort;
        port electricalInterface : ElectricalPort;

        connection powerToSensor connect powerSupply.powerOutput to sensor.power;
        connection sensorToLoad connect sensor.electricalOutput to loadR.input;
        connection loadToConditioner connect loadR.output to conditioner.electricalInput;
        connection externalLight connect opticalInterface to sensor.opticalInput;
        connection externalOutput connect conditioner.electricalInput to electricalInterface;

        perform action systemOperation : MonitorAndProcess {
            in ambientLight = sensor.opticalInput.incidentLight;
            in responsivity = systemResponsivity;
            in gain = systemGain;
            in vcc = supplyVoltage;
            in rLoad = loadResistance;
            out processedSignal;
            out signalLevel;
        }

        state systemState : Phototransistor::OperatingMode;
    }

    requirement def OpticalSensingRequirement {
        doc /* 
            The system shall convert incident optical radiation into 
            proportional electrical current with linear response across 
            the operating range.
        */
        subject opticalSystem : OpticalDetectionSystem;

        require constraint linearResponse {
            doc /* Output current shall be proportional to light intensity */
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* 
            The system shall respond to changes in light intensity 
            within 10 microseconds.
        */
        subject opticalSystem : OpticalDetectionSystem;
    }

    requirement def SensitivityRequirement {
        doc /* 
            The system shall detect light levels from 1 lux to 
            10000 lux with minimum 0.5 A/W responsivity.
        */
        subject opticalSystem : OpticalDetectionSystem;
    }

    requirement systemRequirements {
        doc /* Top-level requirements for phototransistor optical detection system */

        require reqOpticalSensing : OpticalSensingRequirement;
        require reqResponseTime : ResponseTimeRequirement;
        require reqSensitivity : SensitivityRequirement;
    }

    part opticalDetectionSystem : OpticalDetectionSystem {
        satisfy systemRequirements;
    }
}
