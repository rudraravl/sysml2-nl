package 'Fluorescence Image-Guided Surgery System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WavelengthValue :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit = SI::nm;
	}
	
	attribute def FluorescenceIntensity {
		attribute value : Real;
		attribute unit : String;
	}
	
	attribute def ImageResolution {
		attribute width : Integer;
		attribute height : Integer;
	}
	
	attribute def ContrastRatio :> Real;
	
	attribute def ExcitationCommand;
	attribute def ImagingStart;
	attribute def ImagingStop;
	attribute def ResectionComplete;
	
	item def FluorescentDye {
		attribute excitationWavelength : WavelengthValue;
		attribute emissionWavelength : WavelengthValue;
		attribute concentration : Real;
		attribute name : String;
	}
	
	item def RawFluorescenceData {
		attribute intensityMap : FluorescenceIntensity[*];
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def ProcessedImage {
		attribute imageData : Real[*];
		attribute resolution : ImageResolution;
		attribute contrastRatio : ContrastRatio;
	}
	
	item def SurgicalGuidanceOverlay {
		attribute tumorBoundary : Real[*];
		attribute healthyTissue : Real[*];
		attribute resectionMargin : ISQ::LengthValue;
	}
	
	part def NIRLightSource {
		attribute outputWavelength : WavelengthValue;
		attribute outputPower : ISQ::PowerValue;
		port lightOutput;
	}
	
	part def OpticalFilterAssembly {
		attribute excitationFilterWavelength : WavelengthValue;
		attribute emissionFilterWavelength : WavelengthValue;
		attribute transmissionEfficiency : Real;
		port opticalInput;
		port filteredOutput;
	}
	
	part def CCDCamera {
		attribute sensorResolution : ImageResolution;
		attribute quantumEfficiency : Real;
		attribute exposureTime : ISQ::TimeValue;
		port lightInput;
		port dataOutput;
	}
	
	part def ImageProcessingUnit {
		attribute processingLatency : ISQ::TimeValue;
		attribute contrastEnhancement : Real;
		attribute noiseReductionEnabled : Boolean;
		port rawDataInput;
		port processedImageOutput;
		port overlayOutput;
	}
	
	part def SurgicalDisplay {
		attribute screenSize : ISQ::LengthValue;
		attribute brightness : Real;
		attribute refreshRate : ISQ::FrequencyValue;
		port imageInput;
		port overlayInput;
	}
	
	part def TissueField {
		attribute tumorDyeConcentration : Real;
		attribute healthyDyeConcentration : Real;
		attribute tumorSize : ISQ::LengthValue;
		port excitationInput;
		port fluorescenceOutput;
	}
	
	part def DyeInjectionSystem {
		attribute injectionRate : Real;
		attribute totalVolume : ISQ::VolumeValue;
		port dyeOutput;
	}
	
	action def InjectFluorescentDye {
		in dye : FluorescentDye;
		in targetVolume : ISQ::VolumeValue;
		out dyeDistribution : Real;
	}
	
	action def ExciteTissue {
		in excitationLight : WavelengthValue;
		in tissueDyeConcentration : Real;
		out fluorescenceEmission : FluorescenceIntensity;
	}
	
	action def FilterFluorescence {
		in rawEmission : FluorescenceIntensity;
		in filterWavelength : WavelengthValue;
		out filteredSignal : FluorescenceIntensity;
	}
	
	action def AcquireImage {
		in fluorescenceSignal : FluorescenceIntensity;
		in exposureTime : ISQ::TimeValue;
		out rawImageData : RawFluorescenceData;
	}
	
	action def ProcessFluorescenceImage {
		in rawData : RawFluorescenceData;
		in contrastLevel : Real;
		out enhancedImage : ProcessedImage;
		out guidanceOverlay : SurgicalGuidanceOverlay;
	}
	
	action def DisplayGuidance {
		in image : ProcessedImage;
		in overlay : SurgicalGuidanceOverlay;
		out visualFeedback : String;
	}
	
	action def PerformFluorescenceGuidedResection {
		in dyeAgent : FluorescentDye;
		in injectionVolume : ISQ::VolumeValue;
		in excitationWavelength : WavelengthValue;
		out resectionGuidance : SurgicalGuidanceOverlay;
		
		first start;
		then action injectDye : InjectFluorescentDye {
			in dye = dyeAgent;
			in targetVolume = injectionVolume;
			out dyeDistribution;
		}
		then merge continuousImaging;
		then action excite : ExciteTissue {
			in excitationLight = excitationWavelength;
			in tissueDyeConcentration = injectDye.dyeDistribution;
			out fluorescenceEmission;
		}
		then action filter : FilterFluorescence {
			in rawEmission = excite.fluorescenceEmission;
			in filterWavelength = excitationWavelength;
			out filteredSignal;
		}
		then action acquire : AcquireImage {
			in fluorescenceSignal = filter.filteredSignal;
			in exposureTime : ISQ::TimeValue;
			out rawImageData;
		}
		then action process : ProcessFluorescenceImage {
			in rawData = acquire.rawImageData;
			in contrastLevel : Real;
			out enhancedImage;
			out guidanceOverlay;
		}
		then action display : DisplayGuidance {
			in image = process.enhancedImage;
			in overlay = process.guidanceOverlay;
			out visualFeedback;
		}
		then decide;
			if resectionComplete then endProcedure;
			if not resectionComplete then continuousImaging;
		action endProcedure;
		then done;
	}
	
	state def FluorescenceImagingState {
		entry; then standby;
		
		state standby {
			doc /* System is powered and ready but not actively imaging. */
		}
		
		transition standby_to_dyeInjection
			first standby
			accept injectionCmd : ExcitationCommand
			then dyeInjection;
		
		state dyeInjection {
			doc /* Fluorescent dye is being administered to patient. */
		}
		
		transition dyeInjection_to_imaging
			first dyeInjection
			accept imagingStart : ImagingStart
			then activeImaging;
		
		state activeImaging {
			entry; then excitation;
			
			state excitation {
				doc /* NIR light source is illuminating tissue. */
			}
			
			transition excitation_to_acquisition
				first excitation
				then acquisition;
			
			state acquisition {
				doc /* Camera is capturing fluorescence emission. */
			}
			
			transition acquisition_to_processing
				first acquisition
				then processing;
			
			state processing {
				doc /* Image processor is enhancing and overlaying guidance. */
			}
			
			transition processing_to_display
				first processing
				then display;
			
			state display {
				doc /* Surgical display is presenting guidance to surgeon. */
			}
			
			transition display_to_excitation
				first display
				then excitation;
		}
		
		transition imaging_to_standby
			first activeImaging
			accept stopCmd : ImagingStop
			then standby;
	}
	
	part fluorescenceGuidedSurgerySystem {
		doc /* 
			A real-time surgical navigation system that uses fluorescent dyes 
			to visualize tumor tissue boundaries during resection procedures, 
			enabling surgeons to distinguish malignant from healthy tissue 
			and achieve complete tumor removal while preserving critical structures.
		*/
		
		attribute systemName : String = "Fluorescence Image-Guided Surgery System";
		
		part icgDye : FluorescentDye {
			attribute :>> excitationWavelength : WavelengthValue {
				attribute :>> num = 780.0;
			}
			attribute :>> emissionWavelength : WavelengthValue {
				attribute :>> num = 820.0;
			}
			attribute :>> concentration = 2.5;
			attribute :>> name = "Indocyanine Green";
		}
		
		part dyeInjector : DyeInjectionSystem {
			attribute :>> injectionRate = 1.0;
			attribute :>> totalVolume : ISQ::VolumeValue;
		}
		
		part surgicalField : TissueField {
			attribute :>> tumorDyeConcentration = 5.0;
			attribute :>> healthyDyeConcentration = 0.5;
			attribute :>> tumorSize : ISQ::LengthValue;
		}
		
		part nirSource : NIRLightSource {
			attribute :>> outputWavelength : WavelengthValue {
				attribute :>> num = 780.0;
			}
			attribute :>> outputPower : ISQ::PowerValue;
		}
		
		part filterAssembly : OpticalFilterAssembly {
			attribute :>> excitationFilterWavelength : WavelengthValue {
				attribute :>> num = 780.0;
			}
			attribute :>> emissionFilterWavelength : WavelengthValue {
				attribute :>> num = 820.0;
			}
			attribute :>> transmissionEfficiency = 0.95;
		}
		
		part camera : CCDCamera {
			attribute :>> sensorResolution : ImageResolution {
				attribute :>> width = 1920;
				attribute :>> height = 1080;
			}
			attribute :>> quantumEfficiency = 0.90;
			attribute :>> exposureTime : ISQ::TimeValue;
		}
		
		part processor : ImageProcessingUnit {
			attribute :>> processingLatency : ISQ::TimeValue;
			attribute :>> contrastEnhancement = 1.5;
			attribute :>> noiseReductionEnabled = true;
		}
		
		part display : SurgicalDisplay {
			attribute :>> screenSize : ISQ::LengthValue;
			attribute :>> brightness = 500.0;
			attribute :>> refreshRate : ISQ::FrequencyValue;
		}
		
		connect dyeInjector.dyeOutput to surgicalField.excitationInput;
		connect nirSource.lightOutput to filterAssembly.opticalInput;
		connect filterAssembly.filteredOutput to camera.lightInput;
		connect camera.dataOutput to processor.rawDataInput;
		connect processor.processedImageOutput to display.imageInput;
		connect processor.overlayOutput to display.overlayInput;
		
		perform action resectionProcedure : PerformFluorescenceGuidedResection {
			in dyeAgent = icgDye;
			in injectionVolume : ISQ::VolumeValue;
			in excitationWavelength : WavelengthValue {
				attribute :>> num = 780.0;
			}
			out resectionGuidance;
		}
		
		exhibit state systemState : FluorescenceImagingState;
	}
	
	requirement def ImagingPerformanceRequirement {
		doc /* 
			The fluorescence imaging system shall provide real-time visualization 
			of tumor tissue with sufficient contrast and resolution to enable 
			precise surgical resection.
		*/
		
		require constraint tumorContrastRequirement {
			doc /* The system shall achieve a tumor-to-background contrast ratio of at least 3:1. */
		}
		
		require constraint spatialResolutionRequirement {
			doc /* The imaging system shall provide spatial resolution of at least 100 micrometers. */
		}
		
		require constraint temporalResolutionRequirement {
			doc /* The system shall display processed images with latency less than 100 milliseconds. */
		}
		
		require constraint sensitivityRequirement {
			doc /* The system shall detect fluorescence signals at dye concentrations as low as 0.1 micromolar. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* 
			The system shall operate within safe limits for patient tissue exposure 
			and fluorescent dye administration.
		*/
		
		require constraint lightExposureLimit {
			doc /* NIR light power density shall not exceed 50 mW/cm² to prevent tissue thermal damage. */
		}
		
		require constraint dyeDosageLimit {
			doc /* ICG dye concentration shall not exceed 5 mg/kg patient body weight. */
		}
		
		require constraint sterilityRequirement {
			doc /* All patient-contacting components shall maintain sterile field integrity. */
		}
	}
	
	requirement def UsabilityRequirement {
		doc /* 
			The system shall provide intuitive operation and clear visual feedback 
			to support surgical decision-making.
		*/
		
		require constraint displayClarityRequirement {
			doc /* The surgical display shall provide minimum brightness of 400 cd/m² in operating room lighting. */
		}
		
		require constraint colorDifferentiationRequirement {
			doc /* The overlay shall use distinct colors to differentiate tumor from healthy tissue. */
		}
	}
	
	requirement <'FIGS-SYS-001'> systemMissionRequirement {
		doc /* 
			The Fluorescence Image-Guided Surgery System shall enable surgeons to 
			visualize and precisely identify tumor boundaries in real-time during 
			surgical resection procedures, thereby improving complete tumor removal 
			rates while minimizing damage to healthy tissue and critical structures.
		*/
		
		subject system : fluorescenceGuidedSurgerySystem;
		
		assume constraint dyeAccumulationAssumption {
			doc /* 
				Fluorescent dye preferentially accumulates in tumor tissue at concentrations 
				significantly higher than surrounding healthy tissue due to enhanced permeability 
				and retention effect.
			*/
		}
		
		assume constraint opticalAccessAssumption {
			doc /* 
				The surgical field provides adequate optical access for NIR excitation 
				and fluorescence emission detection.
			*/
		}
		
		require imagingPerformance : ImagingPerformanceRequirement;
		require safetyCompliance : SafetyRequirement;
		require usability : UsabilityRequirement;
	}
}
