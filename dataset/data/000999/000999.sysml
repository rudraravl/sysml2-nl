package CalorimeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CalorimetryMode {
        attribute isIsothermal : Boolean;
        attribute isAdiabatic : Boolean;
    }
    
    attribute def SampleProperties {
        attribute mass : MassValue;
        attribute specificHeat : SpecificHeatCapacityValue;
        attribute initialTemperature : ThermodynamicTemperatureValue;
    }
    
    attribute def MeasurementRecord {
        attribute timestamp : DurationValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute heatFlow : PowerValue;
        attribute cumulativeEnergy : EnergyValue;
    }
    
    port def ThermalPort {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute heatFlow : PowerValue;
    }
    
    port def DataPort {
        out measurementData : MeasurementRecord;
    }
    
    port def ControlPort {
        in startMeasurement : Boolean;
        in stopMeasurement : Boolean;
        in setMode : CalorimetryMode;
        out systemStatus : String;
    }
    
    part def SampleChamber {
        attribute volume : VolumeValue;
        attribute currentTemperature : ThermodynamicTemperatureValue;
        attribute sampleProperties : SampleProperties;
        port thermalInterface : ThermalPort;
        
        action containSample {
            in sample : SampleProperties;
            out containedSample : SampleProperties;
        }
    }
    
    part def TemperatureSensor {
        attribute accuracy : ThermodynamicTemperatureValue;
        attribute responseTime : DurationValue;
        port sensingPort : ThermalPort;
        port dataOutput : DataPort;
        
        action measureTemperature {
            in thermalInput : ThermodynamicTemperatureValue;
            out measuredTemperature : ThermodynamicTemperatureValue;
            out measurementTime : DurationValue;
        }
    }
    
    part def HeatingElement {
        attribute maxPower : PowerValue;
        attribute currentPower : PowerValue;
        port thermalOutput : ThermalPort;
        
        action supplyHeat {
            in powerLevel : PowerValue;
            out heatOutput : PowerValue;
        }
    }
    
    part def ThermalInsulation {
        attribute thermalResistance : Real;
        attribute thickness : LengthValue;
        
        action insulateSystem {
            in externalTemperature : ThermodynamicTemperatureValue;
            in internalTemperature : ThermodynamicTemperatureValue;
            out heatLoss : PowerValue;
        }
    }
    
    part def DataAcquisitionSystem {
        attribute samplingRate : Real;
        attribute dataBuffer : MeasurementRecord[*];
        port dataInput : DataPort;
        port controlInterface : ControlPort;
        
        action recordData {
            in measurement : MeasurementRecord;
            out storedData : MeasurementRecord[*];
        }
        
        action calculateHeatCapacity {
            in energyInput : EnergyValue;
            in temperatureChange : ThermodynamicTemperatureValue;
            in sampleMass : MassValue;
            out specificHeatCapacity : SpecificHeatCapacityValue;
        }
    }
    
    part def ControlUnit {
        attribute operatingMode : CalorimetryMode;
        attribute targetTemperature : ThermodynamicTemperatureValue;
        port controlOutput : ControlPort;
        
        action regulateTemperature {
            in currentTemp : ThermodynamicTemperatureValue;
            in targetTemp : ThermodynamicTemperatureValue;
            out powerCommand : PowerValue;
        }
    }
    
    part def Calorimeter;
    
    part calorimeter : Calorimeter {
        doc /* 
         * A calorimeter system for precise measurement of heat capacity 
         * and thermal properties of materials through controlled heating 
         * and temperature monitoring.
         */
        
        part sampleChamber : SampleChamber {
            attribute :>> volume = 50.0 [SI::mL];
            attribute :>> currentTemperature = 298.15 [SI::K];
        }
        
        part temperatureSensor : TemperatureSensor {
            attribute :>> accuracy = 0.01 [SI::K];
            attribute :>> responseTime = 0.1 [SI::s];
        }
        
        part heatingElement : HeatingElement {
            attribute :>> maxPower = 100.0 [SI::W];
            attribute :>> currentPower = 0.0 [SI::W];
        }
        
        part insulation : ThermalInsulation {
            attribute :>> thermalResistance = 10.0;
            attribute :>> thickness = 25.0 [SI::mm];
        }
        
        part dataSystem : DataAcquisitionSystem {
            attribute :>> samplingRate = 10.0;
        }
        
        part controller : ControlUnit {
            attribute :>> targetTemperature = 323.15 [SI::K];
        }
        
        connect sampleChamber.thermalInterface to temperatureSensor.sensingPort;
        connect heatingElement.thermalOutput to sampleChamber.thermalInterface;
        connect temperatureSensor.dataOutput to dataSystem.dataInput;
        connect controller.controlOutput to dataSystem.controlInterface;
        
        perform action measureHeatCapacity {
            first start;
            
            then action loadSample {
                in sampleData : SampleProperties;
                out loadedSample : SampleProperties;
            }
            
            then merge measurementCycle;
            
            then action monitorSystem {
                action readSensor : temperatureSensor.measureTemperature {
                    in thermalInput = sampleChamber.currentTemperature;
                    out measuredTemperature;
                    out measurementTime;
                }
                
                flow readSensor.measuredTemperature to controlHeater.currentTemp;
                
                action controlHeater : controller.regulateTemperature {
                    in currentTemp;
                    in targetTemp = controller.targetTemperature;
                    out powerCommand;
                }
                
                flow controlHeater.powerCommand to applyHeat.powerLevel;
                
                action applyHeat : heatingElement.supplyHeat {
                    in powerLevel;
                    out heatOutput;
                }
                
                action recordMeasurement : dataSystem.recordData {
                    in measurement : MeasurementRecord {
                        attribute :>> timestamp = readSensor.measurementTime;
                        attribute :>> temperature = readSensor.measuredTemperature;
                        attribute :>> heatFlow = applyHeat.heatOutput;
                    }
                    out storedData;
                }
            }
            
            then decide;
                if monitorSystem.readSensor.measuredTemperature >= controller.targetTemperature
                    then computeResults;
                else measurementCycle;
            
            action computeResults {
                action calculateCapacity : dataSystem.calculateHeatCapacity {
                    in energyInput : EnergyValue;
                    in temperatureChange : ThermodynamicTemperatureValue;
                    in sampleMass = sampleChamber.sampleProperties.mass;
                    out specificHeatCapacity;
                }
            }
            
            then done;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* Temperature measurement accuracy requirement */
        subject calorimeter : Calorimeter;
        require constraint {
            calorimeter.temperatureSensor.accuracy <= 0.05 [SI::K]
        }
    }
    
    requirement def ThermalStabilityRequirement {
        doc /* Thermal insulation performance requirement */
        subject calorimeter : Calorimeter;
        require constraint {
            calorimeter.insulation.thermalResistance >= 5.0
        }
    }
    
    requirement def DataAcquisitionRequirement {
        doc /* Minimum data sampling rate requirement */
        subject calorimeter : Calorimeter;
        require constraint {
            calorimeter.dataSystem.samplingRate >= 1.0
        }
    }
    
    requirement <'CAL-001'> calorimeterSystemRequirement {
        doc /* 
         * The calorimeter system shall accurately measure the heat capacity 
         * of material samples by precisely controlling thermal input and 
         * monitoring temperature changes under controlled conditions.
         */
        
        subject calorimeter : Calorimeter;
        
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require thermalStability : ThermalStabilityRequirement;
        require dataAcquisition : DataAcquisitionRequirement;
        
        require constraint operationalRange {
            calorimeter.heatingElement.maxPower >= 50.0 [SI::W] and
            calorimeter.sampleChamber.volume >= 10.0 [SI::mL]
        }
    }
}
