package 'Electronic Nose System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ChemicalConcentration :> ISQ::MassConcentrationValue {
		doc /* Concentration of volatile organic compounds in parts per million */
	}
	
	attribute def SensorResistance :> Real {
		doc /* Electrical resistance of chemical sensor element in ohms */
	}
	
	attribute def SensorResponse {
		attribute resistance : SensorResistance;
		attribute timestamp : ISQ::TimeValue;
		attribute sensorID : Integer;
	}
	
	attribute def OdorSignature {
		attribute volatileCompounds : ChemicalConcentration[*];
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute humidity : Real;
		attribute pressure : ISQ::PressureValue;
	}
	
	attribute def ClassificationResult {
		attribute odorCategory : String;
		attribute confidenceLevel : Real;
		attribute detectedCompounds : String[*];
		attribute analysisTime : ISQ::TimeValue;
	}
	
	port def AirIntakePort {
		in airSample : OdorSignature;
	}
	
	port def SensorDataPort {
		out sensorReadings : SensorResponse[*];
	}
	
	port def AnalysisOutputPort {
		out classification : ClassificationResult;
	}
	
	port def PowerSupplyPort {
		in voltage : ISQ::ElectricPotentialValue;
		in current : ISQ::ElectricCurrentValue;
	}
	
	part def MetalOxideSensor {
		attribute baseResistance : SensorResistance;
		attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute sensitivity : Real;
		
		port exposureIn {
			in chemicalExposure : ChemicalConcentration;
		}
		port responseOut {
			out response : SensorResponse;
		}
		
		action measureChemical {
			in exposure : ChemicalConcentration;
			out reading : SensorResponse;
		}
	}
	
	part def ConductivePolymerSensor {
		attribute nominalResistance : SensorResistance;
		attribute responseTime : ISQ::TimeValue;
		
		port exposureIn {
			in chemicalExposure : ChemicalConcentration;
		}
		port responseOut {
			out response : SensorResponse;
		}
		
		action detectVolatiles {
			in exposure : ChemicalConcentration;
			out reading : SensorResponse;
		}
	}
	
	part def SensorArray {
		attribute arraySize : Integer = 16;
		
		port sampleIn : AirIntakePort;
		port dataOut : SensorDataPort;
		
		part metalOxideSensors : MetalOxideSensor[8] {
			attribute operatingTemperature = 573.15[SI::K];
		}
		
		part polymerSensors : ConductivePolymerSensor[8] {
			attribute responseTime = 2.0[SI::s];
		}
		
		action acquireSensorData {
			in sample : OdorSignature;
			out readings : SensorResponse[*];
			
			action exposeSensors {
				in odorSample : OdorSignature;
			}
			then action collectResponses {
				out sensorData : SensorResponse[*];
			}
		}
	}
	
	part def SignalConditioner {
		port rawDataIn {
			in rawSignals : SensorResponse[*];
		}
		port processedDataOut {
			out processedSignals : SensorResponse[*];
		}
		
		action conditionSignals {
			in raw : SensorResponse[*];
			out conditioned : SensorResponse[*];
			
			action amplifySignals {
				in input : SensorResponse[*];
				out amplified : SensorResponse[*];
			}
			then action filterNoise {
				in amplified : SensorResponse[*];
				out filtered : SensorResponse[*];
			}
			then action normalizeData {
				in filtered : SensorResponse[*];
				out normalized : SensorResponse[*];
			}
		}
	}
	
	part def PatternRecognitionModule {
		attribute trainingDataSize : Integer;
		attribute recognitionAlgorithm : String;
		
		port patternIn {
			in sensorPattern : SensorResponse[*];
		}
		port classificationOut {
			out result : ClassificationResult;
		}
		
		action classifyOdor {
			in pattern : SensorResponse[*];
			out classification : ClassificationResult;
			
			action extractFeatures {
				in sensorData : SensorResponse[*];
				out featureVector : Real[*];
			}
			then action matchPattern {
				in features : Real[*];
				out matchScores : Real[*];
			}
			then action determineCategory {
				in scores : Real[*];
				out category : String;
				out confidence : Real;
			}
		}
	}
	
	part def AirSamplingUnit {
		attribute flowRate : ISQ::VolumeFlowRateValue;
		
		port ambientIn {
			in environmentalAir : OdorSignature;
		}
		port sampleOut {
			out processedSample : OdorSignature;
		}
		
		part pump {
			attribute maxFlowRate : ISQ::VolumeFlowRateValue = 500.0[SI::mL]/1.0[SI::min];
		}
		
		part particleFilter {
			attribute filterSize : ISQ::LengthValue = 0.3[SI::um];
		}
		
		action collectAirSample {
			in ambient : OdorSignature;
			out sample : OdorSignature;
			
			action activatePump;
			then action filterParticles;
			then action deliverSample {
				out cleanedSample : OdorSignature;
			}
		}
	}
	
	part def UserInterface {
		port resultIn {
			in analysisResult : ClassificationResult;
		}
		port displayOut {
			out displayData : ClassificationResult;
		}
		
		action presentResults {
			in results : ClassificationResult;
			
			action formatData {
				in rawResults : ClassificationResult;
				out formattedData : ClassificationResult;
			}
			then action updateDisplay {
				in data : ClassificationResult;
			}
		}
	}
	
	action def AnalyzeOdorSample {
		in airSample : OdorSignature;
		out classification : ClassificationResult;
		out rawSensorData : SensorResponse[*];
	}
	
	part def ElectronicNoseSystem {
		doc /* 
			An electronic nose system that detects and identifies chemical compounds in air 
			by mimicking biological olfaction. The system uses an array of cross-reactive 
			chemical sensors combined with pattern recognition algorithms to classify odors 
			and identify specific volatile organic compounds in environmental samples.
		*/
		
		attribute operatingVoltage : ISQ::ElectricPotentialValue = 5.0[SI::V];
		attribute samplingFrequency : ISQ::FrequencyValue = 0.5[SI::Hz];
		attribute detectionThreshold : ChemicalConcentration = 0.001[SI::g]/1.0[SI::m]**3;
		
		port powerInput : PowerSupplyPort;
		port airIntake : AirIntakePort;
		port analysisOutput : AnalysisOutputPort;
		
		part samplingUnit : AirSamplingUnit {
			attribute flowRate = 300.0[SI::mL]/1.0[SI::min];
		}
		
		part sensorArray : SensorArray;
		
		part signalProcessor : SignalConditioner;
		
		part recognitionEngine : PatternRecognitionModule {
			attribute trainingDataSize = 1000;
			attribute recognitionAlgorithm = "Neural Network";
		}
		
		part userDisplay : UserInterface;
		
		connection sampleFlow connect samplingUnit.sampleOut to sensorArray.sampleIn;
		connection rawDataFlow connect sensorArray.dataOut to signalProcessor.rawDataIn;
		connection processedDataFlow connect signalProcessor.processedDataOut to recognitionEngine.patternIn;
		connection resultFlow connect recognitionEngine.classificationOut to userDisplay.resultIn;
		connection outputFlow connect userDisplay.displayOut to analysisOutput;
		
		action analyzeOdor : AnalyzeOdorSample {
			in airSample : OdorSignature;
			out classification : ClassificationResult;
			out rawSensorData : SensorResponse[*];
			
			first start;
			then action collectSample {
				in ambient = airSample;
				out sample : OdorSignature;
			}
			then action acquireData {
				in sample = collectSample.sample;
				out readings : SensorResponse[*];
			}
			then action processSignals {
				in rawData = acquireData.readings;
				out processedData : SensorResponse[*];
			}
			then action classify {
				in pattern = processSignals.processedData;
				out result : ClassificationResult;
			}
			then action displayResult {
				in results = classify.result;
			}
			then assign classification := classify.result;
			then assign rawSensorData := acquireData.readings;
			then done;
		}
	}
	
	part eNose : ElectronicNoseSystem;
	
	requirement <'ENS-REQ-001'> odorDetectionCapability {
		doc /* 
			The electronic nose system shall detect and classify volatile organic compounds 
			in air samples with a minimum classification accuracy of 90% for trained odor categories.
		*/
		
		subject eNose;
		
		require constraint accuracyConstraint {
			doc /* Classification confidence must be at least 0.90 for valid results */
		}
	}
	
	requirement <'ENS-REQ-002'> responseTimeRequirement {
		doc /* 
			The system shall complete odor analysis from sample collection to classification 
			output within 30 seconds under normal operating conditions.
		*/
		
		subject eNose;
	}
	
	requirement <'ENS-REQ-003'> sensorDiversityRequirement {
		doc /* 
			The sensor array shall contain at least 16 sensors with diverse chemical 
			selectivity patterns to enable discrimination of complex odor mixtures.
		*/
		
		subject eNose.sensorArray;
		
		require constraint diversityConstraint {
			eNose.sensorArray.arraySize >= 16
		}
	}
	
	requirement <'ENS-REQ-004'> detectionSensitivityRequirement {
		doc /* 
			The system shall detect volatile organic compounds at concentrations as low as 
			1 part per million in ambient air samples.
		*/
		
		subject eNose;
		
		require constraint sensitivityConstraint {
			eNose.detectionThreshold <= 0.001[SI::g]/1.0[SI::m]**3
		}
	}
	
	requirement <'ENS-REQ-005'> operationalReliabilityRequirement {
		doc /* 
			The system shall maintain stable sensor baseline readings and consistent 
			classification performance over continuous operation periods of at least 8 hours.
		*/
		
		subject eNose;
	}
}
