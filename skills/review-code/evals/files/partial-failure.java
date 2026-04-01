package com.example.orders;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.List;

/**
 * Processes a batch of orders: validates inventory, charges payment, and updates stock.
 */
public class OrderProcessor {

    private final Connection db;
    private final PaymentClient paymentClient;

    public OrderProcessor(Connection db, PaymentClient paymentClient) {
        this.db = db;
        this.paymentClient = paymentClient;
    }

    public void processBatch(List<Order> orders) throws SQLException {
        for (Order order : orders) {
            // Step 1: Reserve inventory
            try (PreparedStatement stmt = db.prepareStatement(
                    "UPDATE inventory SET reserved = reserved + ? WHERE sku = ? AND available >= ?")) {
                stmt.setInt(1, order.quantity());
                stmt.setString(2, order.sku());
                stmt.setInt(3, order.quantity());
                int updated = stmt.executeUpdate();
                if (updated == 0) {
                    throw new InsufficientInventoryException(order.sku(), order.quantity());
                }
            }

            // Step 2: Charge payment
            paymentClient.charge(order.customerId(), order.totalCents());

            // Step 3: Mark order fulfilled
            try (PreparedStatement stmt = db.prepareStatement(
                    "UPDATE orders SET status = 'fulfilled' WHERE id = ?")) {
                stmt.setString(1, order.id());
                stmt.executeUpdate();
            }
        }
    }

    public record Order(String id, String sku, int quantity, String customerId, long totalCents) {}

    public interface PaymentClient {
        void charge(String customerId, long amountCents);
    }

    public static class InsufficientInventoryException extends RuntimeException {
        public InsufficientInventoryException(String sku, int requested) {
            super("Insufficient inventory for SKU " + sku + ": requested " + requested);
        }
    }
}
