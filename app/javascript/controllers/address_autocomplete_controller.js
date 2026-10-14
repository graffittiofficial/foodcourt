import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "placeId", "addressLine1", "city", "region", "postalCode", "countryCode", "message"]
  static values = { apiKey: String }

  async connect() {
    if (!this.hasApiKeyValue || !this.apiKeyValue.trim()) {
      this.showMessage("Google Places is not configured; an address cannot be selected.")
      return
    }

    try {
      await this.loadPlacesLibrary()
      const { PlaceAutocompleteElement } = await window.google.maps.importLibrary("places")
      this.autocomplete = new PlaceAutocompleteElement()
      this.autocomplete.placeholder = this.inputTarget.placeholder
      this.inputTarget.hidden = true
      this.inputTarget.after(this.autocomplete)
      this.selectHandler = event => this.selectPlace(event)
      this.autocomplete.addEventListener("gmp-select", this.selectHandler)
    } catch (error) {
      console.error("Google Places could not be loaded", error)
      this.showMessage("Address suggestions could not be loaded. Please contact the site administrator.")
    }
  }

  disconnect() {
    this.autocomplete?.removeEventListener("gmp-select", this.selectHandler)
    this.autocomplete?.remove()
    if (this.hasInputTarget) this.inputTarget.hidden = false
  }

  async selectPlace(event) {
    try {
      const place = event.placePrediction.toPlace()
      await place.fetchFields({ fields: ["id", "formattedAddress", "addressComponents"] })
      const components = place.addressComponents || []
      const streetNumber = this.component(components, "street_number")
      const route = this.component(components, "route")
      const city = this.component(components, "locality") || this.component(components, "postal_town")
      const region = this.component(components, "administrative_area_level_1", true)
      const postalCode = this.component(components, "postal_code")
      const countryCode = this.component(components, "country", true)

      if (!place.id || !city || !region || !postalCode || !countryCode) {
        throw new Error("The selected place does not include a complete delivery address.")
      }

      this.placeIdTarget.value = place.id
      this.setTargetValue("addressLine1", [streetNumber, route].filter(Boolean).join(" "))
      this.setTargetValue("city", city)
      this.setTargetValue("region", region)
      this.setTargetValue("postalCode", postalCode)
      this.setTargetValue("countryCode", countryCode.toUpperCase())
      this.inputTarget.value = place.formattedAddress
      this.showMessage(place.formattedAddress)
    } catch (error) {
      this.clearAddress()
      this.showMessage(error.message || "Choose a complete address from the suggestions.")
    }
  }

  async loadPlacesLibrary() {
    if (window.google?.maps?.importLibrary) return
    if (window.foodcourtPlacesLoading) return window.foodcourtPlacesLoading

    window.foodcourtPlacesLoading = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(this.apiKeyValue)}&v=weekly&loading=async`
      script.async = true
      script.onerror = () => reject(new Error("Google Maps JavaScript API failed to load."))
      script.onload = resolve
      document.head.appendChild(script)
    })
    return window.foodcourtPlacesLoading
  }

  component(components, type, shortText = false) {
    const component = components.find(addressComponent => addressComponent.types.includes(type))
    return shortText ? component?.shortText : component?.longText
  }

  clearAddress() {
    this.placeIdTarget.value = ""
    for (const target of ["addressLine1", "city", "region", "postalCode", "countryCode"]) {
      this.setTargetValue(target, "")
    }
  }

  setTargetValue(name, value) {
    const target = `${name}Target`
    if (this[`has${name[0].toUpperCase()}${name.slice(1)}Target`]) this[target].value = value
  }

  showMessage(message) {
    if (this.hasMessageTarget) this.messageTarget.textContent = message
  }
}
