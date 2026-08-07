# Figma AI (yoki dizayner) uchun Barter Loyihasining UI/UX Prompti
*Ushbu hujjatdagi prompt asosan ingliz tilida yozildi, chunki deyarli barcha AI dizayn generatorlari (Figma AI, Uizard, Galileo AI va boshqalar) ingliz tilidagi buyruqlarni eng yaxshi va aniq tushunadi.*

---

## 📋 COPY & PASTE PROMPT FOR FIGMA AGENT (AI DESIGNER)

**Context & Vibe:**
Design a modern, clean, and highly intuitive Mobile App UI (iOS/Android) for a "Barter & Trade" platform called "BarterApp". The app allows B2B (businesses/farmers) and C2C (individuals) to exchange goods directly without cash. The design should evoke trust, clarity, and professionalism. 
- **Colors:** Trust Blue or Deep Green as Primary (representing deals and growth), White/Light Gray background, Gold/Orange for premium highlights.
- **Typography:** Inter, Roboto, or SF Pro. Highly legible.
- **Core Concept:** Unlike standard e-commerce, every post has two sides: "What I Offer" (Give) and "What I Want in Return" (Take). This dual-nature must be visually clear.

Please generate the following 5 core screens in high fidelity:

### 1. Screen: Home / Discovery Feed
- **Header:** Sticky header with User Avatar, current Location/City selector, a Search Bar, and a Notification Bell.
- **Content Area:** A scrollable vertical feed of item cards.
- **Card Design:** 
  - Large thumbnail image of the item.
  - Title (e.g., "40 Tons of Rice").
  - A prominent pill/tag below the title that says "Looking for: Tractors / Vehicles".
  - Bottom row of the card: Estimated Value ($5000) and Distance (5 km away).
- **Bottom Navigation Bar:** 5 icons -> Home, Smart Matches (Sparkle icon), Add Listing (Prominent floating action button in the center), Chat, Profile.

### 2. Screen: Create Listing (Give & Take Form)
- **Header:** "Create Barter" with a close (X) icon.
- **Section 1: "What I Offer"**
  - Horizontal scrollable photo upload boxes.
  - Text inputs for Title, Description.
  - Dropdown for Category.
  - Number input for "Estimated Value (Optional)".
- **Section 2: "What I Want in Return"**
  - UI chips (selectable tags) for desired categories (e.g., [Electronics], [Livestock], [Services], [Any]).
  - A toggle switch (iOS style): "I am willing to add extra cash to the deal".
- **Footer:** A full-width primary button "Publish Listing".

### 3. Screen: Smart Matches (The "Tinder for Trade" Screen)
- **Header:** "Smart Matches" (AI recommended trades).
- **Content:** List of Match Cards.
- **Match Card Layout:**
  - Left side: Thumbnail of *My Item*.
  - Center: A stylish "Exchange/Swap" dual-arrow icon with a circular badge saying "95% Match".
  - Right side: Thumbnail of *Their Item*.
  - Below the images: Text showing "Your [Item] for Their [Item]".
  - Two buttons at the bottom of the card: "Make Offer" (Primary solid) and "Skip" (Ghost/Outline).

### 4. Screen: Make an Offer (Bottom Sheet Modal)
- **Context:** The user wants to trade for an item they see.
- **Header:** "Propose a Trade"
- **Top:** Mini thumbnail of the target item they want.
- **Selection:** "Select from your active items to offer" -> A horizontal carousel of the user's active listings. The user selects one.
- **Input:** "Add Cash (Optional)" -> A sleek input field to add money if the trade is unequal.
- **Action:** Full-width "Send Offer" button.

### 5. Screen: Chat & Negotiation
- **Header:** Back button, User's Name, User's Rating (e.g., 4.8 stars).
- **Pinned Top Banner (Deal Status):** A persistent banner at the top of the chat showing the pending deal. 
  - Text: "My Laptop + $100 <-> Their iPhone 13".
  - Action buttons inside the banner: "Accept Deal" (Green) and "Counter Offer".
- **Chat Area:** Standard chat bubbles for negotiation.
- **Input Area:** Text field, attachment (camera/gallery) icon, send icon.

**Design System Requirements:**
- Use a slight drop shadow on cards to separate them from the light gray background.
- Ensure buttons have enough padding (minimum 48px height for touch targets).
- Include standard status bar and home indicator for modern mobile frames.
