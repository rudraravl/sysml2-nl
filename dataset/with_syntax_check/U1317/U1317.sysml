package StardrawSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CelestialCoordinate {
		attribute rightAscension : Real;
		attribute declination : Real;
	}
	
	attribute def VisualMagnitude :> Real;
	
	attribute def SpectralClass :> String;
	
	item def CelestialObject {
		attribute identifier : String;
		attribute position : CelestialCoordinate;
		attribute magnitude : VisualMagnitude;
		attribute spectralType : SpectralClass;
	}
	
	item def ObservationParameters {
		attribute observerLatitude : Real;
		attribute observerLongitude : Real;
		attribute observationTime : TimeValue;
		attribute fieldOfView : Real;
		attribute magnitudeLimit : VisualMagnitude;
	}
	
	item def CatalogQuery {
		attribute centerRA : Real;
		attribute centerDec : Real;
		attribute searchRadius : Real;
		attribute maxMagnitude : VisualMagnitude;
	}
	
	item def CatalogData {
		attribute objects : CelestialObject[*];
		attribute queryTimestamp : TimeValue;
	}
	
	item def ChartSpecification {
		attribute chartCenter : CelestialCoordinate;
		attribute chartScale : Real;
		attribute chartRotation : Real;
		attribute visibleObjects : CelestialObject[*];
	}
	
	item def RenderedChart {
		attribute imageWidth : LengthValue;
		attribute imageHeight : LengthValue;
		attribute resolution : Real;
		attribute formatType : String;
	}
	
	port def ObservationInputPort {
		in item parameters : ObservationParameters;
	}
	
	port def QueryOutputPort {
		out item query : CatalogQuery;
	}
	
	port def QueryInputPort {
		in item query : CatalogQuery;
	}
	
	port def DataOutputPort {
		out item data : CatalogData;
	}
	
	port def DataInputPort {
		in item data : CatalogData;
	}
	
	port def SpecificationOutputPort {
		out item specification : ChartSpecification;
	}
	
	port def SpecificationInputPort {
		in item specification : ChartSpecification;
	}
	
	port def ChartOutputPort {
		out item chart : RenderedChart;
	}
	
	part def ObservationInterface {
		port parameterInput : ObservationInputPort;
		port queryOutput : QueryOutputPort;
		
		attribute currentParameters : ObservationParameters;
		
		perform action captureObservationRequest {
			in params : ObservationParameters;
			out query : CatalogQuery;
		}
	}
	
	part def CelestialCatalog {
		port queryInput : QueryInputPort;
		port dataOutput : DataOutputPort;
		
		attribute catalogSize : Integer;
		attribute lastUpdate : TimeValue;
		
		perform action retrieveCatalogData {
			in query : CatalogQuery;
			out data : CatalogData;
		}
	}
	
	part def ChartProcessor {
		port dataInput : DataInputPort;
		port observationInput : ObservationInputPort;
		port specificationOutput : SpecificationOutputPort;
		
		attribute processingMode : String;
		
		perform action computeChartSpecification {
			in observations : ObservationParameters;
			in catalogData : CatalogData;
			out specification : ChartSpecification;
		}
	}
	
	part def ChartRenderer {
		port specificationInput : SpecificationInputPort;
		port chartOutput : ChartOutputPort;
		
		attribute renderQuality : Real;
		attribute outputFormat : String;
		
		perform action renderStarChart {
			in specification : ChartSpecification;
			out chart : RenderedChart;
		}
	}
	
	state def StardrawOperationalState {
		entry action initializeSystem;
		
		initial state idle;
		
		state idle {
			doc /* System awaiting observation request. */
		}
		
		state receivingRequest {
			doc /* Capturing and validating observation parameters. */
		}
		
		state queryingCatalog {
			doc /* Retrieving celestial object data from catalog. */
		}
		
		state processingData {
			doc /* Computing chart specification from catalog data. */
		}
		
		state rendering {
			doc /* Generating final star chart visualization. */
		}
		
		state delivering {
			doc /* Outputting completed star chart. */
		}
		
		transition idle_to_receiving
			first idle
			accept request : ObservationParameters
			then receivingRequest;
		
		transition receiving_to_querying
			first receivingRequest
			then queryingCatalog;
		
		transition querying_to_processing
			first queryingCatalog
			then processingData;
		
		transition processing_to_rendering
			first processingData
			then rendering;
		
		transition rendering_to_delivering
			first rendering
			then delivering;
		
		transition delivering_to_idle
			first delivering
			then idle;
	}
	
	action def GenerateStarChart {
		in observationRequest : ObservationParameters;
		out starChart : RenderedChart;
		
		first start;
		
		then action receiveObservation {
			in request : ObservationParameters = observationRequest;
			out validatedRequest : ObservationParameters;
		}
		
		then action formCatalogQuery {
			in params : ObservationParameters = receiveObservation.validatedRequest;
			out query : CatalogQuery;
			
			assign query.centerRA := params.observerLongitude;
			assign query.centerDec := params.observerLatitude;
			assign query.searchRadius := params.fieldOfView;
			assign query.maxMagnitude := params.magnitudeLimit;
		}
		
		then action fetchCatalogData {
			in query : CatalogQuery = formCatalogQuery.query;
			out catalogData : CatalogData;
		}
		
		then action filterVisibleObjects {
			in data : CatalogData = fetchCatalogData.catalogData;
			in params : ObservationParameters = receiveObservation.validatedRequest;
			out filteredObjects : CelestialObject[*];
			
			private attribute selected : CelestialObject[*] := ( );
			
			for obj in data.objects {
				decide;
					if obj.magnitude <= params.magnitudeLimit then includeObject;
					if obj.magnitude > params.magnitudeLimit then skipObject;
				
				action includeObject {
					then assign selected := selected->including(obj);
				}
				
				action skipObject;
			}
			
			assign filteredObjects := selected;
		}
		
		then action createChartSpecification {
			in visibleObjects : CelestialObject[*] = filterVisibleObjects.filteredObjects;
			in params : ObservationParameters = receiveObservation.validatedRequest;
			out specification : ChartSpecification;
			
			assign specification.chartCenter.rightAscension := params.observerLongitude;
			assign specification.chartCenter.declination := params.observerLatitude;
			assign specification.chartScale := 1.0;
			assign specification.chartRotation := 0.0;
			assign specification.visibleObjects := visibleObjects;
		}
		
		then action renderChart {
			in spec : ChartSpecification = createChartSpecification.specification;
			out renderedChart : RenderedChart;
			
			assign renderedChart.imageWidth := 1920.0 [mm];
			assign renderedChart.imageHeight := 1080.0 [mm];
			assign renderedChart.resolution := 300.0;
			assign renderedChart.formatType := "PNG";
		}
		
		then assign starChart := renderChart.renderedChart;
		
		then done;
	}
	
	part def StardrawSystem {
		doc /* 
		 * The Stardraw system is an astronomical visualization platform that generates 
		 * accurate star charts based on observer location, time, and viewing parameters.
		 * Its primary function is to accept observation parameters including geographic 
		 * coordinates, observation time, field of view, and magnitude limit, query a 
		 * comprehensive celestial catalog for relevant objects, filter and process the 
		 * catalog data to identify visible celestial objects, compute precise chart 
		 * specifications accounting for observer perspective and coordinate transformations, 
		 * and render a high-quality star chart visualization suitable for astronomical 
		 * observation planning and educational purposes.
		 */
		
		port observationInput : ObservationInputPort;
		port chartOutput : ChartOutputPort;
		
		perform action generateChart[*] ordered references GenerateStarChart;
		
		part interface : ObservationInterface {
			perform generateChart.receiveObservation;
			perform generateChart.formCatalogQuery;
		}
		
		part catalog : CelestialCatalog {
			perform generateChart.fetchCatalogData;
		}
		
		part processor : ChartProcessor {
			perform generateChart.filterVisibleObjects;
			perform generateChart.createChartSpecification;
		}
		
		part renderer : ChartRenderer {
			perform generateChart.renderChart;
		}
		
		connection inputToInterface connect observationInput to interface.parameterInput;
		connection interfaceToCatalog connect interface.queryOutput to catalog.queryInput;
		connection catalogToProcessor connect catalog.dataOutput to processor.dataInput;
		connection processorToRenderer connect processor.specificationOutput to renderer.specificationInput;
		connection rendererToOutput connect renderer.chartOutput to chartOutput;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The Stardraw system shall generate accurate star charts for specified observation parameters. */
		
		subject stardrawSystem : StardrawSystem;
		
		require constraint chartGeneration {
			doc /* System must produce a star chart for valid observation parameters. */
		}
	}
	
	requirement def CatalogCoverageRequirement {
		doc /* The celestial catalog shall contain objects covering the entire celestial sphere. */
		
		attribute minimumObjects : Integer = 100000;
		
		require constraint catalogCompleteness {
			stardrawSystem.catalog.catalogSize >= minimumObjects
		}
	}
	
	requirement def MagnitudeFilteringRequirement {
		doc /* The system shall filter celestial objects based on specified magnitude limit. */
		
		require constraint magnitudeFiltering {
			doc /* Only objects with magnitude less than or equal to the limit shall be included. */
		}
	}
	
	requirement def RenderingQualityRequirement {
		doc /* Rendered star charts shall meet minimum resolution and quality standards. */
		
		attribute minimumResolution : Real = 150.0;
		
		require constraint renderQuality {
			stardrawSystem.renderer.renderQuality >= minimumResolution
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The system shall generate a star chart within acceptable time limits. */
		
		attribute maximumResponseTime : TimeValue = 5.0 [s];
		
		require constraint responseTime {
			doc /* Chart generation shall complete within maximum response time. */
		}
	}
	
	requirement <'STARDRAW-001'> stardrawSystemRequirements {
		doc /* Top-level requirements for the Stardraw astronomical visualization system. */
		
		subject stardrawSystem : StardrawSystem;
		
		require primaryFunction : PrimaryFunctionRequirement;
		require catalogCoverage : CatalogCoverageRequirement;
		require magnitudeFiltering : MagnitudeFilteringRequirement;
		require renderingQuality : RenderingQualityRequirement;
		require responseTime : ResponseTimeRequirement;
		
		assume constraint validObservationParameters {
			doc /* Input observation parameters must be within valid ranges. */
		}
	}
	
	part stardrawInstance : StardrawSystem;
}
