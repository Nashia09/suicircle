// module suicircle::suicircle;
module suicircle::suicircle {
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::vector;

    // Error codes
    const E_NOT_AUTHORIZED: u64 = 0;
    const E_TRANSFER_NOT_FOUND: u64 = 1;
    const E_INVALID_RECIPIENT: u64 = 2;
    const E_TRANSFER_EXPIRED: u64 = 3;
    const E_INSUFFICIENT_GAS_FEE: u64 = 4;
    const E_ALREADY_CLAIMED: u64 = 5;
    const E_INVALID_SEAL_KEY: u64 = 6;
    const E_TRANSFER_CANCELLED: u64 = 7;

    // Transfer status enum
    const STATUS_PENDING: u8 = 0;
    const STATUS_CLAIMED: u8 = 1;
    const STATUS_EXPIRED: u8 = 2;
    const STATUS_CANCELLED: u8 = 3;

    // File upload struct - for general file uploads
    public struct FileUpload has key, store {
        id: UID,
        file_cid: String,
        filename: String,
        file_size: u64,
        uploader: address,
        upload_timestamp: u64,
    }

    // File transfer struct - core of suiCircle protocol
    public struct FileTransfer has key, store {
        id: UID,
        encrypted_cid: String, // Seal-encrypted content identifier
        metadata_cid: String, // Encrypted metadata (filename, size, type) Wallrus
        sender: address,
        recipient: address,
        created_at: u64,
        expires_at: Option<u64>,
        seal_public_key: vector<u8>,
        encryption_algorithm: String,
        transfer_message: String,
        file_count: u64,
        total_size: u64,
        status: u8,
        access_conditions: Option<AccessCondition>,
        gas_fee_paid: u64,
    }

    // Enhanced access conditions for comprehensive file access control
    public struct AccessCondition has store, drop {
        condition_type: String, // "email", "wallet", "time", "hybrid"

        // Email-based access control
        allowed_emails: vector<String>, // List of allowed email addresses

        // Wallet-based access control
        allowed_addresses: vector<address>, // List of allowed wallet addresses

        // SuiNS-based access control
        allowed_suins_names: vector<String>, // List of allowed SuiNS names (e.g., "user.sui")

        // Time-based access control
        access_start_time: Option<u64>, // When access becomes available
        access_end_time: Option<u64>, // When access expires
        max_access_duration: Option<u64>, // Maximum access duration per user

        // Advanced conditions
        require_all_conditions: bool, // true = AND logic, false = OR logic
        max_access_count: Option<u64>, // Maximum number of times file can be accessed
        current_access_count: u64, // Current access count

        // Additional metadata
        additional_data: vector<u8>,
    }

    // User access record for tracking individual access
    public struct UserAccessRecord has store, drop, copy {
        user_address: address,
        user_email: Option<String>,
        access_timestamp: u64,
        access_count: u64,
        first_access_time: u64,
    }

    // File access control metadata
    public struct FileAccessControl has key, store {
        id: UID,
        file_cid: String,
        owner: address,
        access_condition: AccessCondition,
        user_access_records: vector<UserAccessRecord>,
        created_at: u64,
        updated_at: u64,
    }

    // Global protocol statistics and fee collection
    public struct ProtocolStats has key {
        id: UID,
        total_transfers: u64,
        total_data_transferred: u64,
        gas_fees_collected: Balance<SUI>,
        protocol_fee_rate: u64,
        admin: address,
    }

    // User activity tracking
    public struct UserActivity has key, store {
        id: UID,
        user: address,
        transfers_sent: u64,
        transfers_received: u64,
        total_data_sent: u64,
        total_data_received: u64,
        last_activity: u64,
    }

    // Events
    public struct FileUploadEvent has copy, drop {
        file_cid: String,
        filename: String,
        file_size: u64,
        uploader: address,
        timestamp: u64,
    }

    public struct TransferInitiated has copy, drop {
        transfer_id: address,
        sender: address,
        recipient: address,
        encrypted_cid: String,
        file_count: u64,
        total_size: u64,
        expires_at: Option<u64>,
        gas_fee: u64,
        timestamp: u64,
    }

    public struct TransferClaimed has copy, drop {
        transfer_id: address,
        recipient: address,
        claimed_at: u64,
    }

    public struct TransferCancelled has copy, drop {
        transfer_id: address,
        sender: address,
        cancelled_at: u64,
    }

    public struct GasFeesCollected has copy, drop {
        transfer_id: address,
        fee_amount: u64,
        protocol_fee: u64,
        timestamp: u64,
    }

    // Access control events
    public struct AccessControlCreated has copy, drop {
        file_cid: String,
        owner: address,
        condition_type: String,
        timestamp: u64,
    }

    public struct AccessControlUpdated has copy, drop {
        file_cid: String,
        owner: address,
        condition_type: String,
        timestamp: u64,
    }

    public struct FileAccessGranted has copy, drop {
        file_cid: String,
        user_address: address,
        user_email: Option<String>,
        access_timestamp: u64,
    }

    public struct FileAccessDenied has copy, drop {
        file_cid: String,
        user_address: address,
        reason: String,
        timestamp: u64,
    }

    // Initialize protocol
    fun init(ctx: &mut TxContext) {
        let stats = ProtocolStats {
            id: object::new(ctx),
            total_transfers: 0,
            total_data_transferred: 0,
            gas_fees_collected: balance::zero(),
            protocol_fee_rate: 100, // 1% protocol fee
            admin: tx_context::sender(ctx),
        };
        transfer::share_object(stats);
    }

    // Upload file metadata to the registry
    public entry fun upload_file(
        stats: &mut ProtocolStats,
        file_cid: vector<u8>,
        filename: vector<u8>,
        file_size: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let uploader = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Create file upload record
        let file_upload = FileUpload {
            id: object::new(ctx),
            file_cid: string::utf8(file_cid),
            filename: string::utf8(filename),
            file_size,
            uploader,
            upload_timestamp: timestamp,
        };

        // Update protocol stats
        stats.total_transfers = stats.total_transfers + 1;
        stats.total_data_transferred = stats.total_data_transferred + file_size;

        // Emit upload event
        event::emit(FileUploadEvent {
            file_cid: string::utf8(file_cid),
            filename: string::utf8(filename),
            file_size,
            uploader,
            timestamp,
        });

        // Transfer the file upload object to the uploader
        transfer::transfer(file_upload, uploader);
    }

    // Send files with Seal encryption and wallet-based access
    public entry fun send_files(
        stats: &mut ProtocolStats,
        encrypted_cid: vector<u8>,
        metadata_cid: vector<u8>,
        recipient: address,
        seal_public_key: vector<u8>,
        encryption_algorithm: vector<u8>,
        transfer_message: vector<u8>,
        file_count: u64,
        total_size: u64,
        expires_in_hours: Option<u64>,
        mut gas_fee: Coin<SUI>, // Pass by value to consume the coin
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Calculate expiry time
        let expires_at = if (option::is_some(&expires_in_hours)) {
            let hours = *option::borrow(&expires_in_hours);
            option::some(timestamp + (hours * 3600 * 1000))
        } else {
            option::none()
        };

        // Process gas fee
        let gas_amount = coin::value(&gas_fee);
        assert!(gas_amount > 0, E_INSUFFICIENT_GAS_FEE);
        let protocol_fee = (gas_amount * stats.protocol_fee_rate) / 10000;
        let protocol_fee_coin = coin::split(&mut gas_fee, protocol_fee, ctx);
        balance::join(&mut stats.gas_fees_collected, coin::into_balance(protocol_fee_coin));

        // Return remaining gas to sender
        transfer::public_transfer(gas_fee, sender);

        // Create transfer object
        let transfer_id = object::new(ctx);
        let transfer_addr = object::uid_to_address(&transfer_id);
        let file_transfer = FileTransfer {
            id: transfer_id,
            encrypted_cid: string::utf8(encrypted_cid),
            metadata_cid: string::utf8(metadata_cid),
            sender,
            recipient,
            created_at: timestamp,
            expires_at,
            seal_public_key,
            encryption_algorithm: string::utf8(encryption_algorithm),
            transfer_message: string::utf8(transfer_message),
            file_count,
            total_size,
            status: STATUS_PENDING,
            access_conditions: option::none(),
            gas_fee_paid: gas_amount,
        };

        // Update protocol statistics
        stats.total_transfers = stats.total_transfers + 1;
        stats.total_data_transferred = stats.total_data_transferred + total_size;

        // Update sender activity
        update_user_activity(sender, true, total_size, timestamp, ctx);

        // Share transfer object
        transfer::share_object(file_transfer);

        // Emit transfer initiated event
        event::emit(TransferInitiated {
            transfer_id: transfer_addr,
            sender,
            recipient,
            encrypted_cid: string::utf8(encrypted_cid),
            file_count,
            total_size,
            expires_at,
            gas_fee: gas_amount,
            timestamp,
        });
    }

    // Claim files
    public entry fun claim_transfer(
        transfer: &mut FileTransfer,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let claimer = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        assert!(transfer.recipient == claimer, E_NOT_AUTHORIZED);
        assert!(transfer.status == STATUS_PENDING, E_ALREADY_CLAIMED);

        if (option::is_some(&transfer.expires_at)) {
            let expiry = *option::borrow(&transfer.expires_at);
            assert!(timestamp <= expiry, E_TRANSFER_EXPIRED);
        };

        // Access conditions validation would go here if needed

        transfer.status = STATUS_CLAIMED;

        update_user_activity(claimer, false, transfer.total_size, timestamp, ctx);

        event::emit(TransferClaimed {
            transfer_id: object::uid_to_address(&transfer.id),
            recipient: claimer,
            claimed_at: timestamp,
        });
    }

    // Cancel transfer
    // public entry fun cancel_transfer(
    //     transfer: &mut FileTransfer,
    //     clock: &Clock,
    //     ctx: &mut TxContext
    // ) {
    //     let canceller = tx_context::sender(ctx);
    //     let timestamp = clock::timestamp_ms(clock);

    //     assert!(transfer.sender == canceller, E_NOT_AUTHORIZED);
    //     assert!(transfer.status == STATUS_PENDING, E_TRANSFER_CANCELLED);

    //     transfer.status = STATUS_CANCELLED;
    //     event::emit(TransferCancelled {
    //         transfer_id: object::uid_to_address(&transfer.id),
    //         sender: canceller,
    //         cancelled_at: timestamp,
    //     });
    // }

    // Create access control for a file
    public entry fun create_file_access_control(
        file_cid: vector<u8>,
        condition_type: vector<u8>,
        allowed_emails: vector<vector<u8>>,
        allowed_addresses: vector<address>,
        allowed_suins_names: vector<vector<u8>>,
        access_start_time: Option<u64>,
        access_end_time: Option<u64>,
        max_access_duration: Option<u64>,
        require_all_conditions: bool,
        max_access_count: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let owner = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Convert email vectors to strings
        let mut email_strings = vector::empty<String>();
        let mut i = 0;
        while (i < vector::length(&allowed_emails)) {
            let email_bytes = vector::borrow(&allowed_emails, i);
            vector::push_back(&mut email_strings, string::utf8(*email_bytes));
            i = i + 1;
        };

        // Convert SuiNS name vectors to strings
        let mut suins_strings = vector::empty<String>();
        let mut j = 0;
        while (j < vector::length(&allowed_suins_names)) {
            let suins_bytes = vector::borrow(&allowed_suins_names, j);
            vector::push_back(&mut suins_strings, string::utf8(*suins_bytes));
            j = j + 1;
        };

        let access_condition = AccessCondition {
            condition_type: string::utf8(condition_type),
            allowed_emails: email_strings,
            allowed_addresses,
            allowed_suins_names: suins_strings,
            access_start_time,
            access_end_time,
            max_access_duration,
            require_all_conditions,
            max_access_count,
            current_access_count: 0,
            additional_data: vector::empty(),
        };

        let file_access_control = FileAccessControl {
            id: object::new(ctx),
            file_cid: string::utf8(file_cid),
            owner,
            access_condition,
            user_access_records: vector::empty(),
            created_at: timestamp,
            updated_at: timestamp,
        };

        // Share the access control object
        transfer::share_object(file_access_control);

        // Emit event
        event::emit(AccessControlCreated {
            file_cid: string::utf8(file_cid),
            owner,
            condition_type: string::utf8(condition_type),
            timestamp,
        });
    }

    // Update access control for a file
    public entry fun update_file_access_control(
        access_control: &mut FileAccessControl,
        condition_type: vector<u8>,
        allowed_emails: vector<vector<u8>>,
        allowed_addresses: vector<address>,
        allowed_suins_names: vector<vector<u8>>,
        access_start_time: Option<u64>,
        access_end_time: Option<u64>,
        max_access_duration: Option<u64>,
        require_all_conditions: bool,
        max_access_count: Option<u64>,
        clock: &Clock,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = clock::timestamp_ms(clock);

        // Only owner can update access control
        assert!(access_control.owner == sender, E_NOT_AUTHORIZED);

        // Convert email vectors to strings
        let mut email_strings = vector::empty<String>();
        let mut i = 0;
        while (i < vector::length(&allowed_emails)) {
            let email_bytes = vector::borrow(&allowed_emails, i);
            vector::push_back(&mut email_strings, string::utf8(*email_bytes));
            i = i + 1;
        };

        // Convert SuiNS name vectors to strings
        let mut suins_strings = vector::empty<String>();
        let mut j = 0;
        while (j < vector::length(&allowed_suins_names)) {
            let suins_bytes = vector::borrow(&allowed_suins_names, j);
            vector::push_back(&mut suins_strings, string::utf8(*suins_bytes));
            j = j + 1;
        };

        // Update access condition
        access_control.access_condition = AccessCondition {
            condition_type: string::utf8(condition_type),
            allowed_emails: email_strings,
            allowed_addresses,
            allowed_suins_names: suins_strings,
            access_start_time,
            access_end_time,
            max_access_duration,
            require_all_conditions,
            max_access_count,
            current_access_count: access_control.access_condition.current_access_count,
            additional_data: vector::empty(),
        };

        access_control.updated_at = timestamp;

        // Emit event
        event::emit(AccessControlUpdated {
            file_cid: access_control.file_cid,
            owner: access_control.owner,
            condition_type: string::utf8(condition_type),
            timestamp,
        });
    }

    // Validate file access for a user
    public fun validate_file_access(
        access_control: &mut FileAccessControl,
        user_address: address,
        user_email: Option<String>,
        user_suins: Option<String>,
        clock: &Clock,
        ctx: &TxContext
    ): bool {
        let timestamp = clock::timestamp_ms(clock);
        let condition = &access_control.access_condition;

        // Check if access count limit is reached
        if (option::is_some(&condition.max_access_count)) {
            let max_count = *option::borrow(&condition.max_access_count);
            if (condition.current_access_count >= max_count) {
                event::emit(FileAccessDenied {
                    file_cid: access_control.file_cid,
                    user_address,
                    reason: string::utf8(b"Access count limit reached"),
                    timestamp,
                });
                return false
            };
        };

        let mut email_valid = false;
        let mut address_valid = false;
        let mut suins_valid = false;
        let mut time_valid = false;

        // Check email-based access
        if (vector::length(&condition.allowed_emails) > 0) {
            if (option::is_some(&user_email)) {
                let email = *option::borrow(&user_email);
                email_valid = vector::contains(&condition.allowed_emails, &email);
            };
        } else {
            email_valid = true; // No email restriction
        };

        // Check wallet address-based access
        if (vector::length(&condition.allowed_addresses) > 0) {
            address_valid = vector::contains(&condition.allowed_addresses, &user_address);
        } else {
            address_valid = true; // No address restriction
        };

        // Check SuiNS-based access
        if (vector::length(&condition.allowed_suins_names) > 0) {
            if (option::is_some(&user_suins)) {
                let suins_name = *option::borrow(&user_suins);
                suins_valid = vector::contains(&condition.allowed_suins_names, &suins_name);
            };
        } else {
            suins_valid = true; // No SuiNS restriction
        };

        // Check time-based access
        time_valid = true; // Default to valid

        // Check start time
        if (option::is_some(&condition.access_start_time)) {
            let start_time = *option::borrow(&condition.access_start_time);
            if (timestamp < start_time) {
                time_valid = false;
            };
        };

        // Check end time
        if (option::is_some(&condition.access_end_time)) {
            let end_time = *option::borrow(&condition.access_end_time);
            if (timestamp > end_time) {
                time_valid = false;
            };
        };

        // Check user-specific access duration
        if (option::is_some(&condition.max_access_duration)) {
            let max_duration = *option::borrow(&condition.max_access_duration);
            let user_record = find_user_access_record(&access_control.user_access_records, user_address);

            if (option::is_some(&user_record)) {
                let record = *option::borrow(&user_record);
                if (timestamp - record.first_access_time > max_duration) {
                    time_valid = false;
                };
            };
        };

        // Apply logic (AND vs OR)
        let access_granted = if (condition.require_all_conditions) {
            email_valid && address_valid && suins_valid && time_valid
        } else {
            (email_valid || address_valid || suins_valid) && time_valid
        };

        if (access_granted) {
            // Record the access
            record_user_access(access_control, user_address, user_email, timestamp);

            event::emit(FileAccessGranted {
                file_cid: access_control.file_cid,
                user_address,
                user_email,
                access_timestamp: timestamp,
            });
        } else {
            event::emit(FileAccessDenied {
                file_cid: access_control.file_cid,
                user_address,
                reason: string::utf8(b"Access conditions not met"),
                timestamp,
            });
        };

        access_granted
    }

    // Helper function to find user access record
    fun find_user_access_record(
        records: &vector<UserAccessRecord>,
        user_address: address
    ): Option<UserAccessRecord> {
        let mut i = 0;
        while (i < vector::length(records)) {
            let record = vector::borrow(records, i);
            if (record.user_address == user_address) {
                return option::some(*record)
            };
            i = i + 1;
        };
        option::none()
    }

    // Helper function to record user access
    fun record_user_access(
        access_control: &mut FileAccessControl,
        user_address: address,
        user_email: Option<String>,
        timestamp: u64
    ) {
        // Find existing record or create new one
        let mut found_index = option::none<u64>();
        let mut i = 0;
        while (i < vector::length(&access_control.user_access_records)) {
            let record = vector::borrow(&access_control.user_access_records, i);
            if (record.user_address == user_address) {
                found_index = option::some(i);
                break
            };
            i = i + 1;
        };

        if (option::is_some(&found_index)) {
            // Update existing record
            let index = *option::borrow(&found_index);
            let record = vector::borrow_mut(&mut access_control.user_access_records, index);
            record.access_timestamp = timestamp;
            record.access_count = record.access_count + 1;
        } else {
            // Create new record
            let new_record = UserAccessRecord {
                user_address,
                user_email,
                access_timestamp: timestamp,
                access_count: 1,
                first_access_time: timestamp,
            };
            vector::push_back(&mut access_control.user_access_records, new_record);
        };

        // Increment global access count
        access_control.access_condition.current_access_count =
            access_control.access_condition.current_access_count + 1;
    }

    // Update user activity
    fun update_user_activity(
        user: address,
        is_sender: bool,
        data_size: u64,
        timestamp: u64,
        ctx: &mut TxContext
    ) {
        let activity = UserActivity {
            id: object::new(ctx),
            user,
            transfers_sent: if (is_sender) 1 else 0,
            transfers_received: if (is_sender) 0 else 1,
            total_data_sent: if (is_sender) data_size else 0,
            total_data_received: if (is_sender) 0 else data_size,
            last_activity: timestamp,
        };
        transfer::transfer(activity, user);
    }

    // View functions
    public fun get_transfer_info(transfer: &FileTransfer): (
        String, String, address, address, u64, Option<u64>, u8, u64, u64, u64
    ) {
        (
            transfer.encrypted_cid,
            transfer.metadata_cid,
            transfer.sender,
            transfer.recipient,
            transfer.created_at,
            transfer.expires_at,
            transfer.status,
            transfer.file_count,
            transfer.total_size,
            transfer.gas_fee_paid
        )
    }

    public fun get_seal_info(transfer: &FileTransfer, ctx: &TxContext): (
        vector<u8>, String
    ) {
        assert!(
            transfer.recipient == tx_context::sender(ctx) ||
            transfer.sender == tx_context::sender(ctx),
            E_NOT_AUTHORIZED
        );
        (transfer.seal_public_key, transfer.encryption_algorithm)
    }

    public fun get_protocol_stats(stats: &ProtocolStats): (u64, u64, u64, u64) {
        (
            stats.total_transfers,
            stats.total_data_transferred,
            balance::value(&stats.gas_fees_collected),
            stats.protocol_fee_rate
        )
    }

    public fun can_claim_transfer(transfer: &FileTransfer, user: address, timestamp: u64): bool {
        if (transfer.recipient != user) return false;
        if (transfer.status != STATUS_PENDING) return false;

        if (option::is_some(&transfer.expires_at)) {
            let expiry = *option::borrow(&transfer.expires_at);
            if (timestamp > expiry) return false;
        };

        true
    }

    // View functions for access control
    public fun get_access_control_info(access_control: &FileAccessControl): (
        String, address, String, vector<String>, vector<address>, Option<u64>, Option<u64>, bool, u64, u64
    ) {
        (
            access_control.file_cid,
            access_control.owner,
            access_control.access_condition.condition_type,
            access_control.access_condition.allowed_emails,
            access_control.access_condition.allowed_addresses,
            access_control.access_condition.access_start_time,
            access_control.access_condition.access_end_time,
            access_control.access_condition.require_all_conditions,
            access_control.access_condition.current_access_count,
            vector::length(&access_control.user_access_records)
        )
    }

    public fun get_user_access_records(access_control: &FileAccessControl): vector<UserAccessRecord> {
        access_control.user_access_records
    }

    public fun check_user_access_without_recording(
        access_control: &FileAccessControl,
        user_address: address,
        user_email: Option<String>,
        timestamp: u64
    ): bool {
        let condition = &access_control.access_condition;

        // Check if access count limit is reached
        if (option::is_some(&condition.max_access_count)) {
            let max_count = *option::borrow(&condition.max_access_count);
            if (condition.current_access_count >= max_count) {
                return false
            };
        };

        let mut email_valid = false;
        let mut address_valid = false;
        let mut time_valid = false;

        // Check email-based access
        if (vector::length(&condition.allowed_emails) > 0) {
            if (option::is_some(&user_email)) {
                let email = *option::borrow(&user_email);
                email_valid = vector::contains(&condition.allowed_emails, &email);
            };
        } else {
            email_valid = true;
        };

        // Check wallet address-based access
        if (vector::length(&condition.allowed_addresses) > 0) {
            address_valid = vector::contains(&condition.allowed_addresses, &user_address);
        } else {
            address_valid = true;
        };

        // Check time-based access
        time_valid = true;

        if (option::is_some(&condition.access_start_time)) {
            let start_time = *option::borrow(&condition.access_start_time);
            if (timestamp < start_time) {
                time_valid = false;
            };
        };

        if (option::is_some(&condition.access_end_time)) {
            let end_time = *option::borrow(&condition.access_end_time);
            if (timestamp > end_time) {
                time_valid = false;
            };
        };

        // Check user-specific access duration
        if (option::is_some(&condition.max_access_duration)) {
            let max_duration = *option::borrow(&condition.max_access_duration);
            let user_record = find_user_access_record(&access_control.user_access_records, user_address);

            if (option::is_some(&user_record)) {
                let record = *option::borrow(&user_record);
                if (timestamp - record.first_access_time > max_duration) {
                    time_valid = false;
                };
            };
        };

        // Apply logic (AND vs OR)
        if (condition.require_all_conditions) {
            email_valid && address_valid && time_valid
        } else {
            email_valid || address_valid || time_valid
        }
    }

    // User pays gas fee → 
    // Protocol takes 1% cut → 
    // Protocol fees accumulate → 
    // Admin fee withdraw to their address

    // Admin functions
    public entry fun update_protocol_fee(
        stats: &mut ProtocolStats,
        new_rate: u64,
        ctx: &TxContext
    ) {
        assert!(stats.admin == tx_context::sender(ctx), E_NOT_AUTHORIZED);
        assert!(new_rate <= 1000, E_INSUFFICIENT_GAS_FEE);
        stats.protocol_fee_rate = new_rate;
    }

    public entry fun withdraw_protocol_fees(
        stats: &mut ProtocolStats,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(stats.admin == tx_context::sender(ctx), E_NOT_AUTHORIZED);
        let withdrawal = coin::take(&mut stats.gas_fees_collected, amount, ctx);
        transfer::public_transfer(withdrawal, stats.admin);
    }

    public entry fun emergency_cancel_transfer(
        transfer: &mut FileTransfer,
        stats: &ProtocolStats,
        ctx: &TxContext
    ) {
        assert!(stats.admin == tx_context::sender(ctx), E_NOT_AUTHORIZED);
        transfer.status = STATUS_CANCELLED;
    }
}