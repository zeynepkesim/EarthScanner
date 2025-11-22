const calculateFunctions = {
  calculateRecommendedPrice(form) {
    const transportInput = form.querySelector(
      'select[name="trip[transport_mode]"], input[name="trip[transport_mode]"]'
    );
    const co2Input = form.querySelector('input[name="trip[co2_level]"]');
    const sourceCityInput = form.querySelector(
      'input[name="trip[source_city]"]'
    );
    const destCityInput = form.querySelector(
      'input[name="trip[destination_city]"]'
    );
    const recommendedPriceInput = form.querySelector(
      'input[name="trip[recommended_price]"]'
    );

    if (!transportInput || !recommendedPriceInput) return;

    const transport = transportInput.value;
    const sourceCity = (sourceCityInput?.value || "").trim();
    const destCity = (destCityInput?.value || "").trim();
    const co2 = parseFloat(co2Input?.value) || 0;

    // Show recommended price if transport mode AND (cities OR co2) are provided
    if (!transport || ((!sourceCity || !destCity) && co2 <= 0)) {
      recommendedPriceInput.value = "";
      return;
    }

    // If co2 is provided, use it; otherwise use a default based on cities
    let baseValue = co2;
    if (baseValue <= 0 && sourceCity && destCity) {
      // Use a default CO2 estimate of 100 when cities are filled but co2 is not
      baseValue = 100;
    }

    if (baseValue <= 0) {
      recommendedPriceInput.value = "";
      return;
    }

    // Calculate based on transport mode
    const factor = calculateFunctions.getTransportFactor(transport);
    const recommended = (baseValue * factor * 10).toFixed(2);

    recommendedPriceInput.value = recommended;
  },

  getTransportFactor(mode) {
    const factors = {
      plane: 0.15,
      bus: 0.07,
      train: 0.05,
    };
    return factors[mode] || 0;
  },
};

export const TripFormHook = {
  mounted() {
    const form = this.el.closest("form");
    calculateFunctions.calculateRecommendedPrice(form);

    // Listen for changes on transport_mode, co2_level, and city inputs
    if (form) {
      const transportInput = form.querySelector(
        'select[name="trip[transport_mode]"], input[name="trip[transport_mode]"]'
      );
      const co2Input = form.querySelector('input[name="trip[co2_level]"]');
      const sourceCityInput = form.querySelector(
        'input[name="trip[source_city]"]'
      );
      const destCityInput = form.querySelector(
        'input[name="trip[destination_city]"]'
      );

      if (transportInput) {
        transportInput.addEventListener("change", () =>
          calculateFunctions.calculateRecommendedPrice(form)
        );
      }
      if (co2Input) {
        co2Input.addEventListener("input", () =>
          calculateFunctions.calculateRecommendedPrice(form)
        );
      }
      if (sourceCityInput) {
        sourceCityInput.addEventListener("input", () =>
          calculateFunctions.calculateRecommendedPrice(form)
        );
      }
      if (destCityInput) {
        destCityInput.addEventListener("input", () =>
          calculateFunctions.calculateRecommendedPrice(form)
        );
      }
    }
  },
};

export function initTripForms() {
  // Find all trip forms (both create and edit)
  const forms = document.querySelectorAll('form[action*="/admin/trips"]');
  forms.forEach((form) => {
    calculateFunctions.calculateRecommendedPrice(form);

    const transportInput = form.querySelector(
      'select[name="trip[transport_mode]"], input[name="trip[transport_mode]"]'
    );
    const co2Input = form.querySelector('input[name="trip[co2_level]"]');
    const sourceCityInput = form.querySelector(
      'input[name="trip[source_city]"]'
    );
    const destCityInput = form.querySelector(
      'input[name="trip[destination_city]"]'
    );

    if (transportInput) {
      transportInput.addEventListener("change", () =>
        calculateFunctions.calculateRecommendedPrice(form)
      );
    }
    if (co2Input) {
      co2Input.addEventListener("input", () =>
        calculateFunctions.calculateRecommendedPrice(form)
      );
    }
    if (sourceCityInput) {
      sourceCityInput.addEventListener("input", () =>
        calculateFunctions.calculateRecommendedPrice(form)
      );
    }
    if (destCityInput) {
      destCityInput.addEventListener("input", () =>
        calculateFunctions.calculateRecommendedPrice(form)
      );
    }
  });
}
